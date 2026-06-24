struct GameSpyChallengeMessage {
    let challenge: String

    nonisolated var wireFormat: String {
        GameSpyCodec.encode([("lc", "1"), ("challenge", challenge), ("id", "1")]) + "\\final\\"
    }
}