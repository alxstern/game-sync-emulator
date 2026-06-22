enum DreamAnimation: String, Codable {
    case lookAround           = "LOOK_AROUND"
    case walkAround           = "WALK_AROUND"
    case walkLookAround       = "WALK_LOOK_AROUND"
    case walkVertically       = "WALK_VERTICALLY"
    case walkHorizontally     = "WALK_HORIZONTALLY"
    case walkLookHorizontally = "WALK_LOOK_HORIZONTALLY"
    case spinRight            = "SPIN_RIGHT"
    case spinLeft             = "SPIN_LEFT"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = DreamAnimation(rawValue: raw) ?? .lookAround
    }

    var displayName: String {
        switch self {
        case .lookAround:           return "Look around"
        case .walkAround:           return "Walk around"
        case .walkLookAround:       return "Walk and look around"
        case .walkVertically:       return "Walk up and down"
        case .walkHorizontally:     return "Walk left and right"
        case .walkLookHorizontally: return "Walk left and right and look around"
        case .spinRight:            return "Spin right"
        case .spinLeft:             return "Spin left"
        }
    }
}