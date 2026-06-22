import Foundation

// Reads a 236-byte Gen 5 Pokémon binary structure sent by the DS during Dream World tuck-in.
// The data is encrypted and block-shuffled; we reverse both before reading fields.

enum PokemonInfoReader {

    enum ReadError: Error {
        case invalidSpecies
        case invalidHeldItem
        case invalidAbility
        case levelOutOfRange
        case invalidNature
        case insufficientData
    }

    // Maps personality-derived shuffle index → block reading order (4 entries per row, 24 rows).
    private static let blockShuffleTable: [UInt8] = [
        0, 1, 2, 3,     0, 1, 3, 2,     0, 2, 1, 3,     0, 3, 1, 2,
        0, 2, 3, 1,     0, 3, 2, 1,     1, 0, 2, 3,     1, 0, 3, 2,
        2, 0, 1, 3,     3, 0, 1, 2,     2, 0, 3, 1,     3, 0, 2, 1,
        1, 2, 0, 3,     1, 3, 0, 2,     2, 1, 0, 3,     3, 1, 0, 2,
        2, 3, 0, 1,     3, 2, 0, 1,     1, 2, 3, 0,     1, 3, 2, 0,
        2, 1, 3, 0,     3, 1, 2, 0,     2, 3, 1, 0,     3, 2, 1, 0
    ]

    static func read(from data: Data) throws -> PokemonInfo {
        guard data.count >= 236 else { throw ReadError.insufficientData }
        var bytes = [UInt8](data.prefix(236))

        let personality = readInt32LE(bytes, offset: 0)
        let checksum    = readUInt16LE(bytes, offset: 6)

        decrypt(&bytes, offset: 8,   length: 128, seed: Int32(bitPattern: UInt32(checksum)))
        decrypt(&bytes, offset: 136, length: 100, seed: personality)
        unshuffle(&bytes, personality: personality)

        let species         = Int(readUInt16LE(bytes, offset: 8))
        let heldItem        = Int(readUInt16LE(bytes, offset: 10))
        let trainerId       = Int(readUInt16LE(bytes, offset: 12))
        let trainerSecretId = Int(readUInt16LE(bytes, offset: 14))
        let ability         = Int(bytes[21])
        let form            = Int((bytes[64] >> 3) & 0x1F)
        let genderless      = (bytes[64] >> 2) & 1 == 1
        let female          = (bytes[64] >> 1) & 1 == 1
        let gender: PokemonGender = genderless ? .genderless : female ? .female : .male
        let level           = Int(bytes[140])
        let nickname        = readString(bytes, offset: 72,  maxChars: 20)
        let trainerName     = readString(bytes, offset: 104, maxChars: 14)

        guard let nature = PokemonNature(index: Int(bytes[65])) else { throw ReadError.invalidNature }
        guard species  >= 1  && species  <= 649 else { throw ReadError.invalidSpecies  }
        guard heldItem >= 0  && heldItem <= 638 else { throw ReadError.invalidHeldItem }
        guard ability  >= 1  && ability  <= 164 else { throw ReadError.invalidAbility  }
        guard level    >= 1  && level    <= 100 else { throw ReadError.levelOutOfRange }

        return PokemonInfo(nickname: nickname, trainerName: trainerName, nature: nature,
                           gender: gender, species: species, personality: Int(personality),
                           trainerId: trainerId, trainerSecretId: trainerSecretId,
                           level: level, form: form, ability: ability, heldItem: heldItem)
    }

    // XOR cipher using an LCG. Must use wrapping arithmetic to match Java int overflow.
    private static func decrypt(_ bytes: inout [UInt8], offset: Int, length: Int, seed: Int32) {
        var s = seed
        for i in stride(from: 0, to: length, by: 2) {
            let idx  = offset + i
            let word = UInt16(bytes[idx]) | UInt16(bytes[idx + 1]) << 8
            s = 0x41C64E6D &* s &+ 0x6073
            let mask = UInt16(truncatingIfNeeded: s >> 16)
            let result = word ^ mask
            bytes[idx]     = UInt8(result & 0xFF)
            bytes[idx + 1] = UInt8(result >> 8)
        }
    }

    // Reorders the 4 × 32-byte data blocks back into canonical order (A, B, C, D).
    private static func unshuffle(_ bytes: inout [UInt8], personality: Int32) {
        let shift = Int((Int(personality) & 0x3E000) >> 13) % 24
        var unshuffled = [UInt8](repeating: 0, count: 128)
        for i in 0..<4 {
            let fromBlock  = Int(blockShuffleTable[i + shift * 4])
            let fromOffset = 8 + fromBlock * 32
            let toOffset   = i * 32
            unshuffled[toOffset..<(toOffset + 32)] = bytes[fromOffset..<(fromOffset + 32)]
        }
        bytes.replaceSubrange(8..<136, with: unshuffled)
    }

    private static func readUInt16LE(_ bytes: [UInt8], offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func readInt32LE(_ bytes: [UInt8], offset: Int) -> Int32 {
        Int32(bitPattern: UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24)
    }

    // Reads a null-terminated UTF-16LE string up to maxChars characters.
    private static func readString(_ bytes: [UInt8], offset: Int, maxChars: Int) -> String {
        var scalars: [Unicode.Scalar] = []
        for i in 0..<maxChars {
            let value = UInt32(bytes[offset + i * 2]) | UInt32(bytes[offset + i * 2 + 1]) << 8
            if value == 0 || value == 0xFFFF { break }
            if let scalar = Unicode.Scalar(value) { scalars.append(scalar) }
        }
        return String(String.UnicodeScalarView(scalars))
    }
}