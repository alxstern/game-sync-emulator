struct GameSpyErrorMessage {
    let code: Int
    let message: String
    let id: String

    init(code: Int, message: String, id: String = "1") {
        self.code = code
        self.message = message
        self.id = id
    }

    nonisolated var wireFormat: String {
        GameSpyCodec.encode([
            ("error", ""),
            ("err", String(code)),
            ("fatal", ""),
            ("errmsg", message),
            ("id", id)
        ]) + "\\final\\"
    }
}