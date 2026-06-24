struct GameSpyLoginRequest {
    let authToken: String
    let clientChallenge: String
    let response: String
    let uniqueNick: String
    let gameName: String
    let id: String

    init?(from fields: [String: String]) {
        guard let authToken = fields["authtoken"],
              let clientChallenge = fields["challenge"],
              let response = fields["response"],
              let uniqueNick = fields["uniquenick"],
              let gameName = fields["gamename"] else { return nil }
        self.authToken = authToken
        self.clientChallenge = clientChallenge
        self.response = response
        self.uniqueNick = uniqueNick
        self.gameName = gameName
        self.id = fields["id"] ?? "1"
    }
}