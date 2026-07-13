struct Configuration: Codable {
    var hostName: String
    var clearPlayerDreamInfoOnWake: Bool
    var allowWfcRegistrationThroughLogin: Bool

    static let `default` = Configuration(
        hostName: NetworkUtility.localIPAddress(),
        clearPlayerDreamInfoOnWake: true,
        allowWfcRegistrationThroughLogin: true
    )
}

// All fields use decodeIfPresent so a partial or missing config.json falls back to defaults.
extension Configuration {
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hostName                        = try c.decodeIfPresent(String.self, forKey: .hostName)                        ?? NetworkUtility.localIPAddress()
        clearPlayerDreamInfoOnWake      = try c.decodeIfPresent(Bool.self,   forKey: .clearPlayerDreamInfoOnWake)      ?? true
        allowWfcRegistrationThroughLogin = try c.decodeIfPresent(Bool.self,  forKey: .allowWfcRegistrationThroughLogin) ?? true
    }
}