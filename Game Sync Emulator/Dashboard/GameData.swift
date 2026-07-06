import Foundation

// Species/ability/item name lookups, sourced from bundled JSON (see Resources/NOTICE.md).
enum GameData {
    static let species: [Int: PokemonSpecies] = loadMap("species")
    private static let abilities: [Int: String] = loadMap("abilities")
    private static let items: [Int: String] = loadMap("items")

    static func abilityName(_ id: Int) -> String { abilities[id] ?? "Unknown" }
    static func itemName(_ id: Int) -> String { items[id] ?? "Unknown" }

    // Species available for Dream World encounters, filtered to what the player's own
    // game version can actually receive (Unova species are B2W2-exclusive).
    static func downloadableSpecies(for version: GameVersion?) -> [PokemonSpecies] {
        let isVersion2 = version?.isVersion2 ?? true
        return species.values
            .filter { $0.downloadable && (isVersion2 || $0.id <= 493) }
            .sorted { $0.name < $1.name }
    }

    private static func loadMap<T: Decodable>(_ resource: String) -> [Int: T] {
        guard let url = BundleResource.find("\(resource).json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: T].self, from: data) else {
            log("GameData: failed to load \(resource).json")
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
            Int(key).map { ($0, value) }
        })
    }
}
