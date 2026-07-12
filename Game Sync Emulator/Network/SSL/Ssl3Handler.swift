import Foundation
import NIO
import Security

// Maps session IDs to master secrets so a later connection can resume without a full
// RSA handshake (e.g. SVCLOC reusing the session from NAS login).
private final class Ssl3SessionCache: @unchecked Sendable {
    static let shared = Ssl3SessionCache()
    private var cache = [Data: (masterSecret: [UInt8], cipherSuite: UInt16)]()
    private let lock = NSLock()

    func store(id: [UInt8], masterSecret: [UInt8], cipherSuite: UInt16) {
        lock.lock(); defer { lock.unlock() }
        cache[Data(id)] = (masterSecret, cipherSuite)
    }

    func lookup(id: [UInt8]) -> (masterSecret: [UInt8], cipherSuite: UInt16)? {
        lock.lock(); defer { lock.unlock() }
        return cache[Data(id)]
    }
}

// SSL 3.0 channel handler for Nintendo DS connections.
//
// The DS sends client_version=0x0300 (SSL 3.0) with RC4_128_SHA or RC4_128_MD5 only.
// BoringSSL (used by swift-nio-ssl) dropped SSL 3.0 and RC4, so we implement the handshake
// and record layer directly here. One instance is created per accepted connection.
final class Ssl3Handler: ChannelInboundHandler, ChannelOutboundHandler, @unchecked Sendable {
    typealias InboundIn  = ByteBuffer   // raw TLS bytes from network
    typealias InboundOut = ByteBuffer   // decrypted HTTP bytes for the HTTP pipeline
    typealias OutboundIn = ByteBuffer   // HTTP response bytes from the HTTP pipeline
    typealias OutboundOut = ByteBuffer  // encrypted TLS records to the network

    // MARK: - Handshake state

    private enum State {
        case waitingForClientHello
        case waitingForClientKeyExchange
        case waitingForChangeCipherSpec
        case waitingForClientFinished
        case established
    }

    private var state = State.waitingForClientHello
    private var inBuffer = ByteBufferAllocator().buffer(capacity: 4096)

    // Negotiated session parameters
    private var clientRandom = [UInt8]()
    private var serverRandom = [UInt8]()
    private var cipherSuite: UInt16 = 0x0005  // default RC4_128_SHA; adjusted from ClientHello
    private var useSHA = true
    private var sessionId  = [UInt8]()        // session ID we offered in ServerHello
    private var isResumption = false          // true when doing an abbreviated handshake

    // Keying material (set during ClientKeyExchange)
    private var masterSecret = [UInt8]()
    private var clientMAC    = [UInt8]()
    private var serverMAC    = [UInt8]()
    private var clientRC4    = RC4(key: [0])
    private var serverRC4    = RC4(key: [0])
    private var clientCipherActive = false
    private var readSeqNum:  UInt64 = 0
    private var writeSeqNum: UInt64 = 0

    // Accumulates all plaintext handshake messages (for Finished hash verification)
    private var handshakeMessages = [UInt8]()

    // Certificate and private key (immutable per-server, shared by reference across connections)
    private let serverCertDER: [UInt8]
    private let caCertDER: [UInt8]
    private let privateKey: SecKey

    init(serverCertDER: [UInt8], caCertDER: [UInt8], privateKey: SecKey) {
        self.serverCertDER = serverCertDER
        self.caCertDER     = caCertDER
        self.privateKey    = privateKey
    }

    // MARK: - Inbound path

    func channelActive(context: ChannelHandlerContext) {
        log("SSL3: accepted connection from \(context.remoteAddress?.description ?? "?")")
        context.fireChannelActive()
    }

    func channelInactive(context: ChannelHandlerContext) {
        log("SSL3: connection closed (state=\(state))")
        context.fireChannelInactive()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buf = unwrapInboundIn(data)
        let bytesAdded = buf.readableBytes
        inBuffer.writeBuffer(&buf)
        log("SSL3: channelRead +\(bytesAdded)B state=\(state) bufTotal=\(inBuffer.readableBytes)B")
        processInBuffer(context: context)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        log("SSL3: connection error: \(error)")
        context.close(promise: nil)
    }

    private func processInBuffer(context: ChannelHandlerContext) {
        while let record = readNextRecord() {
            processRecord(record, context: context)
        }
        inBuffer.discardReadBytes()
    }

    private struct SSLRecord {
        let contentType: UInt8
        let data: [UInt8]
    }

    private func readNextRecord() -> SSLRecord? {
        guard inBuffer.readableBytes >= 5 else { return nil }
        let saved = inBuffer.readerIndex
        let contentType = inBuffer.readInteger(as: UInt8.self)!
        let _version    = inBuffer.readInteger(as: UInt16.self)!
        let length      = Int(inBuffer.readInteger(as: UInt16.self)!)
        guard inBuffer.readableBytes >= length else {
            inBuffer.moveReaderIndex(to: saved)
            return nil
        }
        let data = Array(inBuffer.readBytes(length: length)!)
        return SSLRecord(contentType: contentType, data: data)
    }

    private func processRecord(_ record: SSLRecord, context: ChannelHandlerContext) {
        switch record.contentType {
        case 22: // Handshake
            let plain: [UInt8]
            if clientCipherActive {
                let dec = clientRC4.process(record.data)
                readSeqNum += 1
                let macLen = useSHA ? 20 : 16
                plain = Array(dec.dropLast(macLen))
            } else {
                plain = record.data
            }
            processHandshakeData(plain, context: context)

        case 20: // ChangeCipherSpec
            activateClientCipher()

        case 21: // Alert
            log("SSL3: received TLS Alert from DS, closing")
            context.close(promise: nil)

        case 23: // ApplicationData
            guard state == .established else { return }
            let dec = clientRC4.process(record.data)
            readSeqNum += 1
            let macLen = useSHA ? 20 : 16
            let plain = Array(dec.dropLast(macLen))
            var out = context.channel.allocator.buffer(capacity: plain.count)
            out.writeBytes(plain)
            context.fireChannelRead(wrapInboundOut(out))

        default:
            break
        }
    }

    private func processHandshakeData(_ data: [UInt8], context: ChannelHandlerContext) {
        var pos = 0
        while pos + 4 <= data.count {
            let type   = data[pos]
            let length = Int(data[pos+1]) << 16 | Int(data[pos+2]) << 8 | Int(data[pos+3])
            guard pos + 4 + length <= data.count else { break }
            let msg  = Array(data[pos..<pos + 4 + length])
            let body = Array(data[pos+4..<pos + 4 + length])
            switch type {
            case 1:  // ClientHello
                handshakeMessages += msg
                handleClientHello(body, context: context)
            case 16: // ClientKeyExchange
                handshakeMessages += msg
                handleClientKeyExchange(body, context: context)
            case 20: // Finished (arrives encrypted, already decrypted above)
                handleClientFinished(body, context: context)
            default:
                handshakeMessages += msg
            }
            pos += 4 + length
        }
    }

    // MARK: - Individual handshake message handlers

    private func handleClientHello(_ body: [UInt8], context: ChannelHandlerContext) {
        // body: version(2) + random(32) + sessionIdLen(1) + sessionId + csSuiteLen(2) + suites + compLen + comp
        log("SSL3: ClientHello body=\(body.count)B version=\(body.count >= 2 ? String(format: "%02x%02x", body[0], body[1]) : "?")")
        guard body.count >= 34 else { log("SSL3: ClientHello too short"); close(context); return }
        clientRandom = Array(body[2..<34])

        var pos = 34
        guard pos < body.count else { close(context); return }
        let clientSessionIdLen = Int(body[pos]); pos += 1
        let clientSessionId = clientSessionIdLen > 0 && pos + clientSessionIdLen <= body.count
            ? Array(body[pos..<pos + clientSessionIdLen]) : []
        pos += clientSessionIdLen
        guard pos + 2 <= body.count else { close(context); return }
        let csLen = Int(body[pos]) << 8 | Int(body[pos+1]); pos += 2

        var suites = [UInt16]()
        var i = 0
        while i + 2 <= csLen && pos + i + 2 <= body.count {
            suites.append(UInt16(body[pos+i]) << 8 | UInt16(body[pos+i+1]))
            i += 2
        }

        if suites.contains(0x0005) {
            cipherSuite = 0x0005; useSHA = true
        } else if suites.contains(0x0004) {
            cipherSuite = 0x0004; useSHA = false
        } else {
            log("SSL3: no supported cipher suite offered by DS"); close(context); return
        }

        // Resume if the DS offers a known session ID — avoids another slow RSA-1024 decrypt
        // on its end, which matters once a few TLS connections stack up back to back.
        if !clientSessionId.isEmpty, let session = Ssl3SessionCache.shared.lookup(id: clientSessionId) {
            sessionId      = clientSessionId
            masterSecret   = session.masterSecret
            cipherSuite    = session.cipherSuite
            useSHA         = (cipherSuite == 0x0005)
            isResumption   = true
            state          = .waitingForChangeCipherSpec
            log("SSL3: resuming session \(clientSessionId.prefix(4).map { String(format: "%02x", $0) }.joined())")
            sendAbbreviatedServerFlight(context: context)
        } else {
            // Full handshake: generate a new 32-byte session ID so the DS can resume later.
            sessionId    = (0..<32).map { _ in UInt8.random(in: 0...255) }
            isResumption = false
            state        = .waitingForClientKeyExchange
            sendServerFlight(context: context)
        }
    }

    private func handleClientKeyExchange(_ body: [UInt8], context: ChannelHandlerContext) {
        // SSL 3.0 RSA: just the encrypted PreMasterSecret (128 bytes for our 1024-bit key).
        // Some DS implementations include a 2-byte length prefix as in TLS 1.0 — handle both.
        let encrypted: [UInt8]
        switch body.count {
        case 128: encrypted = body
        case 130: encrypted = Array(body[2...])
        default:
            log("SSL3: unexpected ClientKeyExchange length \(body.count)"); close(context); return
        }

        guard let preMasterSecret = rsaDecrypt(encrypted: encrypted) else {
            log("SSL3: RSA PreMasterSecret decrypt failed"); close(context); return
        }

        // master_secret seed = ClientRandom || ServerRandom
        masterSecret = Ssl3Crypto.prf(secret: preMasterSecret, seed: clientRandom + serverRandom, length: 48)
        state = .waitingForChangeCipherSpec
        log("SSL3: master secret derived")
    }

    private func activateClientCipher() {
        if !isResumption {
            // Full handshake: derive session keys now (master secret just arrived).
            let keys = Ssl3Crypto.deriveKeys(
                masterSecret: masterSecret,
                clientRandom: clientRandom,
                serverRandom: serverRandom,
                useSHA: useSHA
            )
            clientMAC   = keys.clientMAC
            serverMAC   = keys.serverMAC
            clientRC4   = RC4(key: keys.clientKey)
            serverRC4   = RC4(key: keys.serverKey)
            readSeqNum  = 0
            writeSeqNum = 0
        }
        // Resumption: keys already derived in sendAbbreviatedServerFlight; just enable decryption.
        clientCipherActive = true
        state = .waitingForClientFinished
        log("SSL3: client cipher active (resumption=\(isResumption))")
    }

    private func handleClientFinished(_ body: [UInt8], context: ChannelHandlerContext) {
        // body = verify_data (36 bytes: MD5(16) + SHA1(20))
        let expected = Ssl3Crypto.finishedHash(
            masterSecret: masterSecret,
            handshakeMessages: handshakeMessages,
            isServer: false
        )
        if body != expected {
            log("SSL3: client Finished mismatch — proceeding anyway")
        }

        if isResumption {
            // Abbreviated handshake: server already sent CCS+Finished; we're done.
            state = .established
            log("SSL3: handshake complete (resumed)")
        } else {
            // Full handshake: add client Finished to accumulator, send server CCS+Finished, store session.
            handshakeMessages += [UInt8(20), 0, 0, UInt8(body.count)] + body
            sendServerFinished(context: context)
            state = .established
            log("SSL3: handshake complete")
            if !sessionId.isEmpty {
                Ssl3SessionCache.shared.store(id: sessionId, masterSecret: masterSecret, cipherSuite: cipherSuite)
                log("SSL3: stored session \(sessionId.prefix(4).map { String(format: "%02x", $0) }.joined())")
            }
        }
    }

    // MARK: - Server message senders

    private func sendServerFlight(context: ChannelHandlerContext) {
        let flight = buildServerHello() + buildCertificate() + buildHandshakeMsg(type: 14, data: [])
        handshakeMessages += flight

        var buf = context.channel.allocator.buffer(capacity: 5 + flight.count)
        buf.writeBytes(makeRecord(type: 22, data: flight))
        context.write(wrapOutboundOut(buf), promise: nil)
        context.flush()
    }

    // Abbreviated handshake for session resumption: ServerHello + ChangeCipherSpec + Finished.
    // No certificate exchange — the DS already has the keys from the prior full handshake.
    private func sendAbbreviatedServerFlight(context: ChannelHandlerContext) {
        let serverHello = buildServerHello()
        handshakeMessages += serverHello

        // Re-derive session keys using the stored master secret and fresh randoms.
        let keys = Ssl3Crypto.deriveKeys(
            masterSecret: masterSecret,
            clientRandom: clientRandom,
            serverRandom: serverRandom,
            useSHA: useSHA
        )
        clientMAC   = keys.clientMAC
        serverMAC   = keys.serverMAC
        clientRC4   = RC4(key: keys.clientKey)
        serverRC4   = RC4(key: keys.serverKey)
        readSeqNum  = 0
        writeSeqNum = 0

        // Server Finished (must be computed before adding it to the accumulator).
        let verifyData  = Ssl3Crypto.finishedHash(masterSecret: masterSecret, handshakeMessages: handshakeMessages, isServer: true)
        let finishedMsg = buildHandshakeMsg(type: 20, data: verifyData)
        // Add server Finished so client Finished verification covers it.
        handshakeMessages += finishedMsg

        let ccs       = makeRecord(type: 20, data: [0x01])
        let mac       = Ssl3Crypto.mac(key: serverMAC, seqNum: writeSeqNum, contentType: 22, data: finishedMsg, useSHA: useSHA)
        writeSeqNum  += 1
        let encrypted  = serverRC4.process(finishedMsg + mac)
        let finRecord  = makeRecord(type: 22, data: encrypted)

        var buf = context.channel.allocator.buffer(capacity: 256)
        buf.writeBytes(makeRecord(type: 22, data: serverHello) + ccs + finRecord)
        context.write(wrapOutboundOut(buf), promise: nil)
        context.flush()
        log("SSL3: sent abbreviated flight (ServerHello + CCS + Finished)")
    }

    private func buildServerHello() -> [UInt8] {
        var random = [UInt8](repeating: 0, count: 32)
        let now = UInt32(Date().timeIntervalSince1970)
        random[0] = UInt8((now >> 24) & 0xFF)
        random[1] = UInt8((now >> 16) & 0xFF)
        random[2] = UInt8((now >> 8)  & 0xFF)
        random[3] = UInt8(now & 0xFF)
        for i in 4..<32 { random[i] = UInt8.random(in: 0...255) }
        serverRandom = random

        var body: [UInt8] = [0x03, 0x00]            // version SSL 3.0
        body += random
        body += [UInt8(sessionId.count)] + sessionId // session ID (32 bytes or 0 for no resumption)
        body += [UInt8(cipherSuite >> 8), UInt8(cipherSuite & 0xFF)]
        body += [0x00]                               // compression = null
        return buildHandshakeMsg(type: 2, data: body)
    }

    private func buildCertificate() -> [UInt8] {
        func entry(_ der: [UInt8]) -> [UInt8] {
            [UInt8(der.count >> 16), UInt8((der.count >> 8) & 0xFF), UInt8(der.count & 0xFF)] + der
        }
        let list = entry(serverCertDER) + entry(caCertDER)
        let body = [UInt8(list.count >> 16), UInt8((list.count >> 8) & 0xFF), UInt8(list.count & 0xFF)] + list
        return buildHandshakeMsg(type: 11, data: body)
    }

    private func sendServerFinished(context: ChannelHandlerContext) {
        let verifyData  = Ssl3Crypto.finishedHash(masterSecret: masterSecret, handshakeMessages: handshakeMessages, isServer: true)
        let finishedMsg = buildHandshakeMsg(type: 20, data: verifyData)

        // ChangeCipherSpec (unencrypted)
        let ccs = makeRecord(type: 20, data: [0x01])

        // Finished is the first record encrypted with serverRC4
        let mac       = Ssl3Crypto.mac(key: serverMAC, seqNum: writeSeqNum, contentType: 22, data: finishedMsg, useSHA: useSHA)
        writeSeqNum  += 1
        let encrypted  = serverRC4.process(finishedMsg + mac)
        let finRecord  = makeRecord(type: 22, data: encrypted)

        let payload = ccs + finRecord
        var buf = context.channel.allocator.buffer(capacity: payload.count)
        buf.writeBytes(payload)
        context.write(wrapOutboundOut(buf), promise: nil)
        context.flush()
    }

    // MARK: - Outbound path (encrypt HTTP responses into SSL records)

    // SSL3/TLS application data records are capped at 2^14 (16384) bytes of plaintext
    // (RFC 6101 §6.2.1) — a conforming client rejects a larger record, so responses bigger
    // than that (e.g. the ~25KB Pokédex skin DLC) must be split across multiple records.
    private static let maxRecordSize = 16384

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        guard state == .established else {
            promise?.succeed()
            return
        }
        var buf = unwrapOutboundIn(data)
        guard let bytes = buf.readBytes(length: buf.readableBytes), !bytes.isEmpty else {
            promise?.succeed(); return
        }
        var out = context.channel.allocator.buffer(capacity: bytes.count + 32)
        for start in stride(from: 0, to: bytes.count, by: Self.maxRecordSize) {
            let chunk     = Array(bytes[start..<min(start + Self.maxRecordSize, bytes.count)])
            let mac       = Ssl3Crypto.mac(key: serverMAC, seqNum: writeSeqNum, contentType: 23, data: chunk, useSHA: useSHA)
            writeSeqNum  += 1
            let encrypted = serverRC4.process(chunk + mac)
            out.writeBytes(makeRecord(type: 23, data: encrypted))
        }
        context.write(wrapOutboundOut(out), promise: promise)
    }

    // Send an SSL3 close_notify alert before the TCP FIN so the DS closes its write side
    // promptly rather than waiting for its own timeout (~2s) to expire.
    func close(context: ChannelHandlerContext, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        if state == .established {
            let alertData: [UInt8] = [0x01, 0x00]  // level=warning, description=close_notify
            let mac       = Ssl3Crypto.mac(key: serverMAC, seqNum: writeSeqNum, contentType: 21, data: alertData, useSHA: useSHA)
            writeSeqNum  += 1
            let encrypted  = serverRC4.process(alertData + mac)
            let record     = makeRecord(type: 21, data: encrypted)
            var buf = context.channel.allocator.buffer(capacity: record.count)
            buf.writeBytes(record)
            context.write(wrapOutboundOut(buf), promise: nil)
            context.flush()
            log("SSL3: sent close_notify")
        }
        context.close(mode: mode, promise: promise)
    }

    // MARK: - Formatting helpers

    private func buildHandshakeMsg(type: UInt8, data: [UInt8]) -> [UInt8] {
        [type, UInt8(data.count >> 16), UInt8((data.count >> 8) & 0xFF), UInt8(data.count & 0xFF)] + data
    }

    private func makeRecord(type: UInt8, data: [UInt8]) -> [UInt8] {
        [type, 0x03, 0x00, UInt8(data.count >> 8), UInt8(data.count & 0xFF)] + data
    }

    private func close(_ context: ChannelHandlerContext) {
        context.close(promise: nil)
    }

    // MARK: - RSA PKCS#1 v1.5 decryption via Security.framework

    private func rsaDecrypt(encrypted: [UInt8]) -> [UInt8]? {
        var cfError: Unmanaged<CFError>?
        guard let result = SecKeyCreateDecryptedData(
            privateKey,
            .rsaEncryptionPKCS1,
            Data(encrypted) as CFData,
            &cfError
        ) else {
            if let err = cfError?.takeRetainedValue() { log("SSL3: RSA decrypt error: \(err)") }
            return nil
        }
        return Array(result as Data)
    }
}
