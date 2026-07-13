import Foundation

// DlcList reads from a writable Application Support directory (so custom user imports can live
// there too), not from the app bundle — so bundled "official" skins/dex skins need to be copied
// in once. dlc-manifest.json (flat filename -> DLC type) stands in for the folder structure that
// Xcode's synchronized groups don't preserve when bundling (Assets/dlc/CGear/BW and .../BW2 both
// flatten into the same Contents/Resources directory).
//
// The bundled filenames themselves (e.g. "038b Red Genesect (B2W2) [PPorg].cgb") are far longer
// than what the reference implementation's own DLC used (~21-28 chars vs. up to 56 here) and are
// suspected of overflowing a fixed-size buffer on the DS — it stops mid-download right after
// receiving a list response naming one of these. So the *seeded* copy gets a short, generated
// name instead; the long bundled name is only ever used locally to find the source file.
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

            // Sorted so the short name assigned to a given bundled file is stable across launches.
            let sortedFilenames = filenames.sorted()
            var expectedNames: Set<String> = []

            for (index, filename) in sortedFilenames.enumerated() {
                let ext = (filename as NSString).pathExtension
                let shortName = "\(type.lowercased())_\(String(format: "%02d", index + 1)).\(ext)"
                expectedNames.insert(shortName)

                let dest = destDir.appendingPathComponent(shortName)
                guard !fm.fileExists(atPath: dest.path) else { continue }
                guard let src = BundleResource.find(filename) else {
                    log("DlcSeeder: bundled file not found for \(filename)")
                    continue
                }
                do {
                    try fm.copyItem(at: src, to: dest)
                } catch {
                    log("DlcSeeder: failed to copy \(filename) -> \(shortName): \(error)")
                }
            }

            // Remove anything left over from a previous seeding (e.g. the old long-named files).
            if let existing = try? fm.contentsOfDirectory(at: destDir, includingPropertiesForKeys: nil) {
                for file in existing where !expectedNames.contains(file.lastPathComponent) {
                    try? fm.removeItem(at: file)
                    log("DlcSeeder: removed stale seeded file \(file.lastPathComponent)")
                }
            }
        }
    }
}
