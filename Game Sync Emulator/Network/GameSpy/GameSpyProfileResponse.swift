struct GameSpyProfileResponse {
    let userId: String
    let profile: GameProfile
    let uniqueNick: String
    let id: String

    nonisolated var wireFormat: String {
        GameSpyCodec.encode([
            ("pi", ""),
            ("userid", userId),
            ("profileid", String(profile.id)),
            ("nick", uniqueNick),
            ("uniquenick", uniqueNick),
            ("email", ""),
            ("firstname", profile.firstName ?? ""),
            ("lastname", profile.lastName ?? ""),
            ("aim", profile.aimName ?? ""),
            ("zipcode", profile.zipCode ?? ""),
            ("sig", "40404040404040404040404040404040"),
            ("namespaceid", "1"),
            ("id", id)
        ]) + "\\final\\"
    }
}