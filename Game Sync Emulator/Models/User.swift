import Foundation

struct User: Codable {
    let id: String
    let password: String
    var profiles: [String: GameProfile]

    // Runtime-only — not persisted to JSON.
    var dlcOverrides: [String: Dlc] = [:]
    // When non-zero, overrides the profile ID sent to the DS. Lets users manually fix WFC error 60000,
    // which occurs when the server's profile ID falls out of sync with the cartridge.
    var profileIdOverride: Int = 0

    enum CodingKeys: String, CodingKey {
        case id, password, profiles
    }

    init(id: String, password: String) {
        self.id = id
        self.password = password
        self.profiles = [:]
    }

    // "123456789" → "1234-5678-9000"
    var formattedId: String {
        let padded = id + "000"
        return stride(from: 0, to: padded.count, by: 4).map { i -> String in
            let start = padded.index(padded.startIndex, offsetBy: i)
            let end   = padded.index(start, offsetBy: 4, limitedBy: padded.endIndex) ?? padded.endIndex
            return String(padded[start..<end])
        }.joined(separator: "-")
    }

    var redactedId: String { String(id.prefix(4)) + "-XXXX-XXXX-XXXX" }

    func profile(for branchCode: String) -> GameProfile? { profiles[branchCode] }
    func dlcOverride(for type: String) -> Dlc?           { dlcOverrides[type] }
    func hasDlcOverride(for type: String) -> Bool         { dlcOverrides[type] != nil }

    mutating func setDlcOverride(_ dlc: Dlc?, for type: String) {
        dlcOverrides[type] = dlc
    }
}

extension User {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,       forKey: .id)
        try c.encode(password, forKey: .password)
        try c.encode(profiles, forKey: .profiles)
    }

    nonisolated init(from decoder: Decoder) throws {
        let c   = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(String.self, forKey: .id)
        password = try c.decode(String.self, forKey: .password)
        profiles = try c.decodeIfPresent([String: GameProfile].self, forKey: .profiles) ?? [:]
        dlcOverrides    = [:]
        profileIdOverride = 0
    }
}