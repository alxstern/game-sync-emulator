import Foundation

enum PokemonGender: String, Codable {
    case male = "MALE"
    case female = "FEMALE"
    case genderless = "GENDERLESS"

    // Defaults to male when decoding an unrecognised value, matching the original behaviour.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PokemonGender(rawValue: raw) ?? .male
    }

    var displayName: String { rawValue.capitalized }
}
