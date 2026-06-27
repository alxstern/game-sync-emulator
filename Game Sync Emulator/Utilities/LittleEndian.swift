import Foundation

// LittleEndianReader reads typed values sequentially from a Data buffer.
// LittleEndianWriter builds a Data buffer by appending typed values.

struct LittleEndianReader {
    private let data: Data
    private var offset: Int = 0

    init(_ data: Data) {
        self.data = data
    }

    mutating func readShort() -> Int16 {
        let v = UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
        offset += 2
        return Int16(bitPattern: v)
    }

    mutating func readInt() -> Int32 {
        let v = UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
        offset += 4
        return Int32(bitPattern: v)
    }

    mutating func readFloat() -> Float {
        Float(bitPattern: UInt32(bitPattern: readInt()))
    }

    mutating func readLong() -> Int64 {
        let v = UInt64(data[offset])
            | UInt64(data[offset + 1]) << 8
            | UInt64(data[offset + 2]) << 16
            | UInt64(data[offset + 3]) << 24
            | UInt64(data[offset + 4]) << 32
            | UInt64(data[offset + 5]) << 40
            | UInt64(data[offset + 6]) << 48
            | UInt64(data[offset + 7]) << 56
        offset += 8
        return Int64(bitPattern: v)
    }

    mutating func readDouble() -> Double {
        Double(bitPattern: UInt64(bitPattern: readLong()))
    }

    // Reads a fixed-length UTF-16LE string, stopping at a 0xFFFF terminator.
    mutating func readUTF16(length: Int) -> String {
        var chars: [Character] = []
        var read = 0

        for _ in 0..<length {
            let v = UInt32(data[offset]) | UInt32(data[offset + 1]) << 8
            offset += 2
            if v == 0xFFFF { break }
            if let scalar = Unicode.Scalar(v) {
                chars.append(Character(scalar))
            }
            read += 1
        }

        let remaining = length - (read + 1)
        if remaining > 0 { offset += remaining * 2 }

        return String(chars)
    }

    mutating func skip(_ count: Int) {
        offset += count
    }
}

struct LittleEndianWriter {
    var data = Data()

    mutating func writeBytes(_ byte: UInt8, count: Int) {
        data.append(contentsOf: repeatElement(byte, count: count))
    }

    mutating func writeShort(_ value: Int16) {
        let v = UInt16(bitPattern: value)
        data.append(UInt8(v & 0xFF))
        data.append(UInt8(v >> 8))
    }

    mutating func writeInt(_ value: Int32) {
        let v = UInt32(bitPattern: value)
        data.append(UInt8(v & 0xFF))
        data.append(UInt8((v >> 8) & 0xFF))
        data.append(UInt8((v >> 16) & 0xFF))
        data.append(UInt8((v >> 24) & 0xFF))
    }

    mutating func writeFloat(_ value: Float) {
        writeInt(Int32(bitPattern: value.bitPattern))
    }

    mutating func writeLong(_ value: Int64) {
        let v = UInt64(bitPattern: value)
        for i in 0..<8 {
            data.append(UInt8((v >> (8 * i)) & 0xFF))
        }
    }

    mutating func writeDouble(_ value: Double) {
        writeLong(Int64(bitPattern: value.bitPattern))
    }
}
