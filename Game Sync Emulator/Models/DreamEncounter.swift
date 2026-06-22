struct DreamEncounter: Codable, Equatable {
    let species: Int
    let move: Int
    let form: Int
    let gender: PokemonGender
    let animation: DreamAnimation
}

// gender may be absent in older save files; default to genderless (random gender in-game).
extension DreamEncounter {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        species   = try c.decode(Int.self,                        forKey: .species)
        move      = try c.decode(Int.self,                        forKey: .move)
        form      = try c.decode(Int.self,                        forKey: .form)
        gender    = try c.decodeIfPresent(PokemonGender.self,     forKey: .gender) ?? .genderless
        animation = try c.decode(DreamAnimation.self,             forKey: .animation)
    }
}