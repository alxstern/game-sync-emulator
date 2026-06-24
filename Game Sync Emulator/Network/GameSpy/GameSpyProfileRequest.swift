struct GameSpyProfileRequest {
    let sessKey: String
    let profileId: Int
    let id: String

    init?(from fields: [String: String]) {
        guard let sessKey = fields["sesskey"],
              let profileIdStr = fields["profileid"],
              let profileId = Int(profileIdStr) else { return nil }
        self.sessKey = sessKey
        self.profileId = profileId
        self.id = fields["id"] ?? "2"
    }
}