import Foundation
import CommonCrypto
import CryptoKit

enum Ssl3Crypto {

    // MARK: - Hash primitives

    static func sha1(_ bytes: [UInt8]) -> [UInt8] {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        CC_SHA1(bytes, CC_LONG(bytes.count), &digest)
        return digest
    }

    private static func md5(_ bytes: [UInt8]) -> [UInt8] {
        Array(Insecure.MD5.hash(data: Data(bytes)))
    }

    // MARK: - SSL 3.0 PRF
    //
    // output = MD5(secret || SHA1('A'*1 || secret || seed)) ||
    //          MD5(secret || SHA1('B'*2 || secret || seed)) || ...

    static func prf(secret: [UInt8], seed: [UInt8], length: Int) -> [UInt8] {
        var output = [UInt8]()
        var n = 0
        while output.count < length {
            let label = [UInt8](repeating: UInt8(65 + n), count: n + 1)
            output += md5(secret + sha1(label + secret + seed))
            n += 1
        }
        return Array(output.prefix(length))
    }

    // MARK: - Key derivation

    struct SessionKeys {
        let clientMAC: [UInt8]
        let serverMAC: [UInt8]
        let clientKey: [UInt8]
        let serverKey: [UInt8]
    }

    // key_block seed is ServerRandom || ClientRandom (reversed from master secret)
    static func deriveKeys(masterSecret: [UInt8], clientRandom: [UInt8], serverRandom: [UInt8], useSHA: Bool) -> SessionKeys {
        let macLen = useSHA ? 20 : 16
        let keyLen = 16  // RC4_128
        let block = prf(secret: masterSecret, seed: serverRandom + clientRandom, length: (macLen + keyLen) * 2)
        var off = 0
        let cMAC = Array(block[off..<off + macLen]); off += macLen
        let sMAC = Array(block[off..<off + macLen]); off += macLen
        let cKey  = Array(block[off..<off + keyLen]); off += keyLen
        let sKey  = Array(block[off..<off + keyLen])
        return SessionKeys(clientMAC: cMAC, serverMAC: sMAC, clientKey: cKey, serverKey: sKey)
    }

    // MARK: - SSL 3.0 MAC
    //
    // mac = hash(key || pad2 || hash(key || pad1 || seqNum || contentType || length || data))
    // No version field in SSL 3.0 MAC (unlike TLS 1.0).

    static func mac(key: [UInt8], seqNum: UInt64, contentType: UInt8, data: [UInt8], useSHA: Bool) -> [UInt8] {
        let padLen = useSHA ? 40 : 48
        let pad1 = [UInt8](repeating: 0x36, count: padLen)
        let pad2 = [UInt8](repeating: 0x5C, count: padLen)
        var seq = [UInt8](repeating: 0, count: 8)
        for i in 0..<8 { seq[7 - i] = UInt8((seqNum >> (i * 8)) & 0xFF) }
        let len: [UInt8] = [UInt8(data.count >> 8), UInt8(data.count & 0xFF)]
        let inner = key + pad1 + seq + [contentType] + len + data
        let outer = key + pad2
        return useSHA ? sha1(outer + sha1(inner)) : md5(outer + md5(inner))
    }

    // MARK: - SSL 3.0 Finished verify_data
    //
    // verify_data = MD5(ms || pad2_48 || MD5(msgs || sender || ms || pad1_48)) ||
    //              SHA1(ms || pad2_40 || SHA1(msgs || sender || ms || pad1_40))

    static func finishedHash(masterSecret: [UInt8], handshakeMessages: [UInt8], isServer: Bool) -> [UInt8] {
        let sender: [UInt8] = isServer ? [0x53, 0x52, 0x56, 0x52] : [0x43, 0x4C, 0x4E, 0x54]  // SRVR / CLNT
        let pad1_48 = [UInt8](repeating: 0x36, count: 48)
        let pad2_48 = [UInt8](repeating: 0x5C, count: 48)
        let pad1_40 = [UInt8](repeating: 0x36, count: 40)
        let pad2_40 = [UInt8](repeating: 0x5C, count: 40)
        let md5Part  = md5(masterSecret  + pad2_48 + md5(handshakeMessages  + sender + masterSecret + pad1_48))
        let sha1Part = sha1(masterSecret + pad2_40 + sha1(handshakeMessages + sender + masterSecret + pad1_40))
        return md5Part + sha1Part
    }
}
