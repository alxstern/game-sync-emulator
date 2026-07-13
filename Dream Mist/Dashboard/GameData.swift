import Foundation

// Species/ability/item name lookups, sourced from bundled JSON (see Resources/NOTICE.md).
enum GameData {
    static let species: [Int: PokemonSpecies] = loadMap("species")
    private static let abilities: [Int: String] = loadMap("abilities")
    private static let items: [Int: String] = loadMap("items")
    private static let countries: [Int: Country] = loadMap("countries")

    static func abilityName(_ id: Int) -> String { abilities[id] ?? "Unknown" }
    static func itemName(_ id: Int) -> String { items[id] ?? "Unknown" }

    // Species available for Dream World encounters, filtered to what the player's own
    // game version can actually receive (Unova species are B2W2-exclusive).
    static func downloadableSpecies(for version: GameVersion?) -> [PokemonSpecies] {
        let isVersion2 = version?.isVersion2 ?? true
        return allSpeciesList.filter { $0.downloadable && (isVersion2 || $0.id <= 493) }
    }

    static func allItems() -> [ItemOption] { allItemsList }

    static func country(_ id: Int) -> Country? { countries[id] }

    static func allCountries() -> [Country] { allCountriesList }

    // Unfiltered, unlike downloadableSpecies(for:) — used where a species is just cosmetic
    // flavor (e.g. the Pokémon a Join Avenue visitor is dreaming of).
    static func allSpecies() -> [PokemonSpecies] { allSpeciesList }

    // Sorted once and reused. These view structs (AvenueEditorView, ItemsEditorView, etc.)
    // recompute their `let` properties on every reconstruction, which SwiftUI does on every
    // keystroke/picker change while they're on screen — re-sorting 649 species or 130
    // countries per keystroke was the main cause of Join Avenue feeling sluggish.
    private static let allSpeciesList: [PokemonSpecies] = species.values.sorted { $0.id < $1.id }
    private static let allCountriesList: [Country] = countries.values.sorted { $0.name < $1.name }
    private static let allItemsList: [ItemOption] = items
        .map { ItemOption(id: $0.key, name: $0.value) }
        .sorted { $0.id < $1.id }

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

struct ItemOption: Identifiable, Equatable {
    let id: Int
    let name: String
}
