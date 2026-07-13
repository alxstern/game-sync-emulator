struct DlsRequest {
    let serviceToken: String
    let action: String
    let dlcGameCode: String  // from "gamecd" — the game serial requesting DLC
    let dlcName: String?     // from "contents" — used by action=contents
    let dlcType: String      // from "attr1" — DLC type, may include region suffix (e.g. "CGEAR_E")
    let dlcIndex: Int        // from "attr2" — DLC slot index; 0 means none
    let offset: Int          // from "offset" — start offset into the list (unused so far — logged for now)
    let num: Int             // from "num" — number of entries requested (unused so far — logged for now)
    let rawFields: [String: String]

    init?(from fields: [String: String]) {
        guard let token  = fields["token"],
              let action = fields["action"] else { return nil }
        self.serviceToken = token
        self.action       = action
        self.dlcGameCode  = fields["gamecd"] ?? ""
        self.dlcName      = fields["contents"]
        self.dlcType      = fields["attr1"] ?? ""
        self.dlcIndex     = Int(fields["attr2"] ?? "") ?? 0
        self.offset       = Int(fields["offset"] ?? "") ?? 0
        self.num          = Int(fields["num"] ?? "") ?? 0
        self.rawFields    = fields
    }
}
