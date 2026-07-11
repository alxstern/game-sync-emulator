import Foundation

// DlcList reads from a writable Application Support directory (so custom user imports can live
// there too), not from the app bundle — so bundled "official" skins/dex skins need to be copied
// in once. dlc-manifest.json (flat filename -> DLC type) stands in for the folder structure that
// Xcode's synchronized groups don't preserve when bundling (Assets/dlc/CGear/BW and .../BW2 both
// flatten into the same Contents/Resources directory).
enum DlcSeeder {
    static func seed(into dlcDirectory: URL) {
        guard let manifestURL = BundleResource.find("dlc-manifest.json"),
              let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            log("DlcSeeder: failed to load dlc-manifest.json")
            return
        }

        let fm = FileManager.default

        for (type, filenames) in manifest {
            let destDir = dlcDirectory.appendingPathComponent("IRAO").appendingPathComponent(type)
            try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)

            for filename in filenames {
                let dest = destDir.appendingPathComponent(filename)
                guard !fm.fileExists(atPath: dest.path) else { continue }
                guard let src = BundleResource.find(filename) else {
                    log("DlcSeeder: bundled file not found for \(filename)")
                    continue
                }
                do {
                    try fm.copyItem(at: src, to: dest)
                } catch {
                    log("DlcSeeder: failed to copy \(filename): \(error)")
                }
            }
        }
    }
}
