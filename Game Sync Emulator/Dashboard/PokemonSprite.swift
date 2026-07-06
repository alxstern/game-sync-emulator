import AppKit

// Loads sprite images matching the folder layout in Dashboard/Resources/Sprites/pokemon
// (pokemon/, pokemon/female/, pokemon/shiny/, pokemon/shiny/female/).
enum PokemonSprite {
    static func image(for info: PokemonInfo) -> NSImage? {
        guard let species = GameData.species[info.species] else { return nil }
        let female = info.gender == .female && species.hasFemaleSprite == true

        var components = ["pokemon"]
        if info.isShiny { components.append("shiny") }
        if female { components.append("female") }
        components.append("\(fileNameStem(species: species, form: info.form)).gif")

        guard let url = BundleResource.find(components) else { return nil }
        return NSImage(contentsOf: url)
    }

    private static func fileNameStem(species: PokemonSpecies, form: Int) -> String {
        guard form != 0, let forms = species.forms, form < forms.count else {
            return "\(species.id)"
        }
        return "\(species.id)-\(formSuffix(forms[form].name))"
    }

    // Verified against the actual downloaded sprite set: PokeAPI names form variants by a
    // lowercased slug of the form name, not the numeric form index the original Java code
    // uses. Every one of Gen V's 20 form-having species follows "first word, lowercased"
    // except Unown's punctuation forms.
    private static func formSuffix(_ formName: String) -> String {
        switch formName {
        case "!": return "exclamation"
        case "?": return "question"
        default:
            let firstWord = formName.split(separator: " ").first.map(String.init) ?? formName
            return firstWord.lowercased()
        }
    }
}
