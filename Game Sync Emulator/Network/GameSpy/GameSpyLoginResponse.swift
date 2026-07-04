struct GameSpyLoginResponse {
    let sessKey: Int
    let proof: String
    let userId: String
    let profileId: Int
    let id: String

    nonisolated var wireFormat: String {
        GameSpyCodec.encode([
            ("lc",        "2"),
            ("userid",    userId),
            ("profileid", String(profileId)),
            ("proof",     proof),
            ("sesskey",   String(sessKey)),
            ("id",        id)
        ]) + "\\final\\"
    }
}