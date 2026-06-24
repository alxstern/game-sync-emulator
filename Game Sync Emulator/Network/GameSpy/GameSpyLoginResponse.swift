struct GameSpyLoginResponse {
    let sessKey: Int
    let proof: String
    let userId: String
    let profileId: Int
    let uniqueNick: String
    let id: String

    nonisolated var wireFormat: String {
        GameSpyCodec.encode([
            ("lc", "2"),
            ("sesskey", String(sessKey)),
            ("proof", proof),
            ("userid", userId),
            ("profileid", String(profileId)),
            ("uniquenick", uniqueNick),
            ("lt", "000000000000000000000000000000"),
            ("id", id)
        ]) + "\\final\\"
    }
}