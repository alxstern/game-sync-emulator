struct PglRequest {
    let gameSyncId: String?  // from "gsid" integer PID field, converted via GSIDUtility.stringify
    let type: String         // from "p" field
    let token: String        // from "tok" field
    let romCode: Int         // from "rom" field
    let languageCode: Int    // from "langcode" field

    var gameVersion: GameVersion? {
        GameVersion.lookup(romCode: romCode, languageCode: languageCode)
    }

    init?(from fields: [String: String]) {
        guard let type  = fields["p"],
              let token = fields["tok"] else { return nil }
        self.type  = type
        self.token = token

        // The "gsid" field is the raw 32-bit personality ID as a decimal integer.
        // GSIDUtility.stringify converts it to the 10-char base-32 Game Sync ID string.
        if let gsidStr = fields["gsid"], let pid = Int32(gsidStr) {
            self.gameSyncId = GSIDUtility.stringify(pid)
        } else {
            self.gameSyncId = nil
        }

        self.romCode      = Int(fields["rom"]      ?? "") ?? 0
        self.languageCode = Int(fields["langcode"] ?? "") ?? 0
    }
}
