struct NasRequest {
    let userId: String
    let password: String
    let macAddress: String
    let action: String
    let branchCode: String?  // action=login only
    let serviceType: String? // action=SVCLOC only

    init?(from fields: [String: String]) {
        guard let userId     = fields["userid"],
              let password   = fields["passwd"],
              let macAddress = fields["macadr"],
              let action     = fields["action"] else { return nil }
        self.userId     = userId
        self.password   = password
        self.macAddress = macAddress
        self.action     = action
        self.branchCode  = fields["gsbrcd"]
        self.serviceType = fields["svc"]
    }
}
