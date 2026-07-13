import Foundation

enum PokemonNature: String, Codable, CaseIterable {
    case hardy    = "HARDY"
    case lonely   = "LONELY"
    case brave    = "BRAVE"
    case adamant  = "ADAMANT"
    case naughty  = "NAUGHTY"
    case bold     = "BOLD"
    case docile   = "DOCILE"
    case relaxed  = "RELAXED"
    case impish   = "IMPISH"
    case lax      = "LAX"
    case timid    = "TIMID"
    case hasty    = "HASTY"
    case serious  = "SERIOUS"
    case jolly    = "JOLLY"
    case naive    = "NAIVE"
    case modest   = "MODEST"
    case mild     = "MILD"
    case quiet    = "QUIET"
    case bashful  = "BASHFUL"
    case rash     = "RASH"
    case calm     = "CALM"
    case gentle   = "GENTLE"
    case sassy    = "SASSY"
    case careful  = "CAREFUL"
    case quirky   = "QUIRKY"

    // The DS encodes nature as an index into this ordered list.
    init?(index: Int) {
        guard index >= 0 && index < Self.allCases.count else { return nil }
        self = Self.allCases[index]
    }

    // Defaults to hardy when decoding an unrecognised value, matching the original behaviour.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PokemonNature(rawValue: raw) ?? .hardy
    }

    var displayName: String { rawValue.capitalized }
}
