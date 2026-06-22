enum AvenueVisitorType: String, Codable {
    case youngster        = "YOUNGSTER"
    case lass             = "LASS"
    case aceTrainerMale   = "ACE_TRAINER_MALE"
    case aceTrainerFemale = "ACE_TRAINER_FEMALE"
    case rangerMale       = "RANGER_MALE"
    case rangerFemale     = "RANGER_FEMALE"
    case breederMale      = "BREEDER_MALE"
    case breederFemale    = "BREEDER_FEMALE"
    case scientistMale    = "SCIENTIST_MALE"
    case scientistFemale  = "SCIENTIST_FEMALE"
    case hiker            = "HIKER"
    case parasolLady      = "PARASOL_LADY"
    case roughneck        = "ROUGHNECK"
    case nurse            = "NURSE"
    case preschoolerMale  = "PRESCHOOLER_MALE"
    case preschoolerFemale = "PRESCHOOLER_FEMALE"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AvenueVisitorType(rawValue: raw) ?? .youngster
    }

    var displayName: String {
        switch self {
        case .youngster:         return "Youngster"
        case .lass:              return "Lass"
        case .aceTrainerMale:    return "Ace Trainer♂"
        case .aceTrainerFemale:  return "Ace Trainer♀"
        case .rangerMale:        return "Pokémon Ranger♂"
        case .rangerFemale:      return "Pokémon Ranger♀"
        case .breederMale:       return "Pokémon Breeder♂"
        case .breederFemale:     return "Pokémon Breeder♀"
        case .scientistMale:     return "Scientist♂"
        case .scientistFemale:   return "Scientist♀"
        case .hiker:             return "Hiker"
        case .parasolLady:       return "Parasol Lady"
        case .roughneck:         return "Roughneck"
        case .nurse:             return "Nurse"
        case .preschoolerMale:   return "Preschooler♂"
        case .preschoolerFemale: return "Preschooler♀"
        }
    }

    // Numeric ID the game client uses to look up this trainer class.
    var clientId: Int {
        switch self {
        case .youngster, .lass:                   return 0
        case .aceTrainerMale, .aceTrainerFemale:  return 1
        case .rangerMale, .rangerFemale:          return 2
        case .breederMale, .breederFemale:        return 3
        case .scientistMale, .scientistFemale:    return 4
        case .hiker, .parasolLady:                return 5
        case .roughneck, .nurse:                  return 6
        case .preschoolerMale, .preschoolerFemale: return 7
        }
    }

    var isFemale: Bool {
        switch self {
        case .lass, .aceTrainerFemale, .rangerFemale, .breederFemale,
             .scientistFemale, .parasolLady, .nurse, .preschoolerFemale:
            return true
        default:
            return false
        }
    }
}