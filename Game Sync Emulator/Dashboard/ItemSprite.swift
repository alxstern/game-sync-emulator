import AppKit

// Loads item icons bundled from Assets/items ({id}.png, sourced from Bulbapedia — see
// Resources/NOTICE.md). Unlike Pokémon sprites, every icon is a uniform 24x24, so there's no
// relative-scale concern here.
enum ItemSprite {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(for id: Int) -> NSImage? {
        let key = "\(id)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let url = BundleResource.find("\(id).png") else {
            return nil
        }
        guard let image = NSImage(contentsOf: url) else {
            log("ItemSprite: found \(url.path) but NSImage failed to decode it")
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }
}
