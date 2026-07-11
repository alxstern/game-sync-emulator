import AppKit

// Loads overworld trainer sprites bundled from Sprites/trainers, named {rawValue lowercased}.png
// to match AvenueVisitorType directly (e.g. ACE_TRAINER_MALE -> ace_trainer_male.png).
enum AvenueVisitorSprite {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(for type: AvenueVisitorType) -> NSImage? {
        let key = type.rawValue as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let url = BundleResource.find("\(type.rawValue.lowercased()).png") else {
            return nil
        }
        guard let image = NSImage(contentsOf: url) else {
            log("AvenueVisitorSprite: found \(url.path) but NSImage failed to decode it")
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }
}
