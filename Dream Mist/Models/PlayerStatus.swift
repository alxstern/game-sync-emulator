enum PlayerStatus: String, Codable {
    case awake     = "AWAKE"
    case sleeping  = "SLEEPING"
    case dreaming  = "DREAMING"
    case wakeReady = "WAKE_READY"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PlayerStatus(rawValue: raw) ?? .awake
    }
}