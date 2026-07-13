import Foundation

// Locates bundled resources by their trailing path components (e.g. "pokemon", "shiny", "1.gif")
// rather than assuming a specific flattened-vs-nested bundle layout. Xcode's file-system-
// synchronized groups are expected to preserve on-disk folder structure, but this doesn't
// depend on getting that assumption exactly right.
enum BundleResource {
    static func find(_ pathComponents: String...) -> URL? {
        find(pathComponents)
    }

    static func find(_ pathComponents: [String]) -> URL? {
        guard let name = pathComponents.last else { return nil }
        let nameNoExt = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        let subdirectory = pathComponents.dropLast().joined(separator: "/")

        if let url = Bundle.main.url(forResource: nameNoExt, withExtension: ext, subdirectory: subdirectory.isEmpty ? nil : subdirectory) {
            return url
        }
        return suffixIndex[pathComponents.joined(separator: "/")]
    }

    // Maps every file in the bundle to its trailing 1-, 2-, and 3-component path suffixes,
    // so a lookup for "pokemon/shiny/1.gif" finds the file regardless of what (if anything)
    // Xcode nested it under, while still distinguishing it from "pokemon/female/1.gif".
    private static let suffixIndex: [String: URL] = {
        guard let resourceURL = Bundle.main.resourceURL,
              let enumerator = FileManager.default.enumerator(at: resourceURL, includingPropertiesForKeys: nil) else {
            return [:]
        }
        var result: [String: URL] = [:]
        for case let url as URL in enumerator {
            let components = url.pathComponents
            let depth = min(3, components.count)
            for start in stride(from: components.count - 1, through: components.count - depth, by: -1) {
                result[components[start...].joined(separator: "/")] = url
            }
        }
        return result
    }()
}
