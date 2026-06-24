import Foundation

// Responds to any DNS query with a single A record pointing to hostIP,
// redirecting all DS hostname lookups to this machine.
enum DnsQueryHandler {

    nonisolated static func respond(to data: Data, hostIP: String) -> Data? {
        let bytes = [UInt8](data)
        guard bytes.count >= 12 else { return nil }

        // Bit 7 of flags byte 0: QR flag — must be 0 (query) not 1 (response).
        guard bytes[2] & 0x80 == 0 else { return nil }

        let questionCount = (Int(bytes[4]) << 8) | Int(bytes[5])
        guard questionCount >= 1 else { return nil }

        // Walk the QNAME labels (each prefixed with a length byte, terminated by 0x00).
        var offset = 12
        while offset < bytes.count && bytes[offset] != 0 {
            let labelLength = Int(bytes[offset])
            guard offset + 1 + labelLength < bytes.count else { return nil }
            offset += 1 + labelLength
        }
        // Skip null terminator (1) + QTYPE (2) + QCLASS (2).
        guard offset + 5 <= bytes.count else { return nil }
        offset += 5

        let ipParts = hostIP.split(separator: ".").compactMap { UInt8($0) }
        guard ipParts.count == 4 else { return nil }

        // Start the response by copying the query (header + question section), then patch the header.
        var response = Array(bytes[0..<offset])
        response[2] = 0x81  // QR=1 (response), RD=1 (recursion desired, echo from query)
        response[3] = 0x80  // RA=1 (recursion available)
        response[6] = 0x00  // ANCOUNT high byte
        response[7] = 0x01  // ANCOUNT low byte = 1

        // Answer section.
        response += [0xC0, 0x0C]               // NAME: pointer to offset 12 (the question name)
        response += [0x00, 0x01]               // TYPE: A
        response += [0x00, 0x01]               // CLASS: IN
        response += [0x00, 0x00, 0x00, 0x3C]  // TTL: 60 seconds
        response += [0x00, 0x04]               // RDLENGTH: 4 bytes
        response += ipParts                    // RDATA: IPv4 address

        return Data(response)
    }
}