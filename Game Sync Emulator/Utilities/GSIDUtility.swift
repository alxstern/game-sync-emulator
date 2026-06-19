// A Game Sync ID is a 10-character string that encodes a 32-bit personality ID (PID)
// plus a 16-bit CRC-16 checksum into a base-32 alphabet that avoids visually ambiguous
// characters (no 0, 1, I, or O).
//
// Encoding: pack the PID into the low 32 bits of a 48-bit value and the checksum into
// the high 16 bits, then read 5 bits at a time (least-significant first) to index into
// the character table, producing 10 characters.

enum GSIDUtility {

    static let chartable = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func stringify(_ pid: Int32) -> String {
        let checksum = Int64(CRC16.calc(pid))
        let ugsid = Int64(pid) | (checksum << 32)
        var chars = [Character](repeating: " ", count: 10)

        for i in 0..<10 {
            let index = Int((ugsid >> (5 * i)) & 0x1F)
            chars[i] = chartable[index]
        }

        return String(chars)
    }

    static func isValid(_ gsid: String) -> Bool {
        guard gsid.count == 10 else { return false }

        var ugsid: Int64 = 0

        for (i, char) in gsid.enumerated() {
            guard let pos = chartable.firstIndex(of: char) else { return false }
            ugsid |= Int64(pos) << (5 * i)
        }

        let output = Int32(truncatingIfNeeded: ugsid & 0xFFFFFFFF)
        let checksum = Int((ugsid >> 32) & 0xFFFF)
        return output >= 0 && CRC16.calc(output) == checksum
    }
}
