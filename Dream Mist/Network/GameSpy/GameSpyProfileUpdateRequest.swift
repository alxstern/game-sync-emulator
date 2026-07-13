struct GameSpyProfileUpdateRequest {
    let sessKey: String
    let firstName: String?
    let lastName: String?
    let aimName: String?
    let zipCode: String?
    let id: String

    init?(from fields: [String: String]) {
        guard let sessKey = fields["sesskey"] else { return nil }
        self.sessKey = sessKey
        self.firstName = fields["firstname"]
        self.lastName = fields["lastname"]
        self.aimName = fields["aim"]
        self.zipCode = fields["zipcode"]
        self.id = fields["id"] ?? "1"
    }
}