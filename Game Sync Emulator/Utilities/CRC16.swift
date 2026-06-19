// CRC-16/CCITT-FALSE (polynomial 0x1021, initial value 0xFFFF).
// Used to validate DLC checksums and to compute Game Sync ID check digits.

enum CRC16 {

    static func calc(_ input: [UInt8], offset: Int = 0, length: Int? = nil) -> Int {
        let count = length ?? (input.count - offset)
        var crc = 0xFFFF

        for i in offset..<(offset + count) {
            crc ^= Int(input[i]) << 8
            for _ in 0..<8 {
                if crc & 0x8000 != 0 {
                    crc = (crc << 1) ^ 0x1021
                } else {
                    crc <<= 1
                }
            }
        }

        return crc & 0xFFFF
    }

    // Computes the checksum of the four little-endian bytes of a 32-bit integer.
    static func calc(_ input: Int32) -> Int {
        calc([
            UInt8(truncatingIfNeeded: input),
            UInt8(truncatingIfNeeded: input >> 8),
            UInt8(truncatingIfNeeded: input >> 16),
            UInt8(truncatingIfNeeded: input >> 24),
        ])
    }
}
