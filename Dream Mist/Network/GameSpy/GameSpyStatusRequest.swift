struct GameSpyStatusRequest {
    let status: String
    let statString: String
    let locString: String

    init(from fields: [String: String]) {
        self.status = fields["status"] ?? ""
        self.statString = fields["statstring"] ?? ""
        self.locString = fields["locstring"] ?? ""
    }
}