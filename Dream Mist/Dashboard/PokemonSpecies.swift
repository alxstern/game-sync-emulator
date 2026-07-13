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

// downloadable is absent (not just false) for ~100 species in the original JSON — Jackson
// defaults a non-required primitive boolean to false in that case, so match that here rather
// than treating it as a required key, which would fail decoding for the whole species map.
extension PokemonSpecies {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(Int.self,                     forKey: .id)
        name            = try c.decode(String.self,                  forKey: .name)
        downloadable    = try c.decodeIfPresent(Bool.self,            forKey: .downloadable) ?? false
        gender          = try c.decodeIfPresent(PokemonGender.self,   forKey: .gender)
        hasFemaleSprite = try c.decodeIfPresent(Bool.self,            forKey: .hasFemaleSprite)
        forms           = try c.decodeIfPresent([PokemonForm].self,   forKey: .forms)
    }
}
