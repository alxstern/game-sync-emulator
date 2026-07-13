struct PokemonInfo: Codable {
    let nickname: String
    let trainerName: String
    let nature: PokemonNature
    let gender: PokemonGender
    let species: Int
    let personality: Int
    let trainerId: Int
    let trainerSecretId: Int
    let level: Int
    let form: Int
    let ability: Int
    let heldItem: Int

    var isShiny: Bool {
        let p1 = (personality >> 16) & 0xFFFF
        let p2 = personality & 0xFFFF
        return (trainerId ^ trainerSecretId ^ p1 ^ p2) < 8
    }
}

// form, ability, and heldItem may be absent in older save files.
extension PokemonInfo {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nickname        = try c.decode(String.self,         forKey: .nickname)
        trainerName     = try c.decode(String.self,         forKey: .trainerName)
        nature          = try c.decode(PokemonNature.self,  forKey: .nature)
        gender          = try c.decode(PokemonGender.self,  forKey: .gender)
        species         = try c.decode(Int.self,            forKey: .species)
        personality     = try c.decode(Int.self,            forKey: .personality)
        trainerId       = try c.decode(Int.self,            forKey: .trainerId)
        trainerSecretId = try c.decode(Int.self,            forKey: .trainerSecretId)
        level           = try c.decode(Int.self,            forKey: .level)
        form            = try c.decodeIfPresent(Int.self,   forKey: .form)     ?? 0
        ability         = try c.decodeIfPresent(Int.self,   forKey: .ability)  ?? 0
        heldItem        = try c.decodeIfPresent(Int.self,   forKey: .heldItem) ?? 0
    }
}