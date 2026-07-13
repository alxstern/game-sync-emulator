import AppKit

// Loads sprite images bundled from Assets/pokemon. Xcode's synchronized groups flatten all
// loose resource files straight into Contents/Resources regardless of source folder nesting —
// there's no "pokemon/" subdirectory in the built bundle, just uniquely-named flat files:
// {id}.gif, {id}_f.gif, {id}_shiny.gif, {id}_f_shiny.gif.
enum PokemonSprite {
    // Decoding a multi-frame GIF isn't free, and image(for:)/image(species:...) get called on
    // every body re-evaluation (tab switches, any picker change) — cache by filename so a given
    // sprite is only ever read from disk and decoded once per app run.
    private static let cache = NSCache<NSString, NSImage>()

    static func image(for info: PokemonInfo) -> NSImage? {
        guard let species = GameData.species[info.species] else {
            log("PokemonSprite: no species entry for id \(info.species) (species.json has \(GameData.species.count) entries)")
            return nil
        }
        return image(species: species, form: info.form, gender: info.gender, shiny: info.isShiny)
    }

    static func image(species: PokemonSpecies, form: Int, gender: PokemonGender, shiny: Bool) -> NSImage? {
        let female = gender == .female && species.hasFemaleSprite == true

        var filename = fileNameStem(species: species, form: form)
        if female { filename += "_f" }
        if shiny { filename += "_shiny" }
        filename += ".gif"

        let key = filename as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let url = BundleResource.find(filename) else {
            log("PokemonSprite: could not resolve \(filename) in bundle")
            return nil
        }
        guard let image = NSImage(contentsOf: url) else {
            log("PokemonSprite: found \(url.path) but NSImage failed to decode it")
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
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
