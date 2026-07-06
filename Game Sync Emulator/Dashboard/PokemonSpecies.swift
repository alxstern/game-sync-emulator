import Foundation

struct PokemonForm: Codable, Hashable {
    let id: Int
    let name: String
}

struct PokemonSpecies: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let downloadable: Bool
    let gender: PokemonGender?
    let hasFemaleSprite: Bool?
    let forms: [PokemonForm]?

    // Species with no fixed gender (most of them) can be either; a few are locked to one.
    var genders: [PokemonGender] {
        gender.map { [$0] } ?? [.male, .female]
    }
}
