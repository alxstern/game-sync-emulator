import Foundation

final class DlcList: @unchecked Sendable {

    private let entries: [Dlc]

    init(dataDirectory: URL) {
        var loaded: [Dlc] = []
        let fm = FileManager.default

        guard let gameCodeDirs = try? fm.contentsOfDirectory(at: dataDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) else {
            entries = []
            return
        }

        for gameCodeDir in gameCodeDirs {
            guard (try? gameCodeDir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                log("Warning: Non-directory '\(gameCodeDir.lastPathComponent)' in DLC root folder")
                continue
            }

            let gameCode = gameCodeDir.lastPathComponent

            guard let typeDirs = try? fm.contentsOfDirectory(at: gameCodeDir, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) else { continue }

            for typeDir in typeDirs {
                guard (try? typeDir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                    log("Warning: Non-directory '\(typeDir.lastPathComponent)' in DLC subfolder '\(gameCode)'")
                    continue
                }

                let type = typeDir.lastPathComponent
                var index = 1

                guard let dlcFiles = try? fm.contentsOfDirectory(at: typeDir, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) else { continue }

                for dlcFile in dlcFiles {
                    let name = dlcFile.lastPathComponent

                    if name == "none" || name == "custom" {
                        log("Warning: DLC '\(gameCode)/\(type)/\(name)' uses a reserved name")
                        continue
                    }

                    if let dlc = Self.load(file: dlcFile, gameCode: gameCode, type: type, index: index) {
                        loaded.append(dlc)
                        index += 1
                    }
                }
            }
        }

        entries = loaded
        let missingChecksumCount = loaded.filter { !$0.checksumEmbedded }.count
        let suffix = missingChecksumCount > 0
            ? " (\(missingChecksumCount) without an embedded checksum — appended automatically when served)"
            : ""
        log("Loaded \(loaded.count) DLC file(s)\(suffix)")
    }

    private static func load(file: URL, gameCode: String, type: String, index: Int) -> Dlc? {
        let name = file.lastPathComponent

        guard (try? file.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory != true else {
            log("Warning: Directory '\(name)' in \(gameCode) DLC folder")
            return nil
        }

        guard let data = try? Data(contentsOf: file) else {
            log("Error: Could not read DLC file at \(file.path)")
            return nil
        }

        let bytes = Array(data)
        let storedChecksum  = Int(bytes[bytes.count - 2]) | (Int(bytes[bytes.count - 1]) << 8)
        let computedChecksum = CRC16.calc(bytes, offset: 0, length: bytes.count - 2)

        if computedChecksum == storedChecksum {
            return Dlc(path: file, name: name, gameCode: gameCode, type: type,
                       index: index, projectedSize: bytes.count,
                       checksum: computedChecksum, checksumEmbedded: true)
        } else {
            // No embedded checksum — expected for most bundled skin rips. DlsHandler appends
            // a freshly computed one when serving the file; see the summary log in init above.
            let fullChecksum = CRC16.calc(bytes)
            return Dlc(path: file, name: name, gameCode: gameCode, type: type,
                       index: index, projectedSize: bytes.count + 2,
                       checksum: fullChecksum, checksumEmbedded: false)
        }
    }

    // MARK: Lookups

    func dlcs(gameCode: String, type: String, index: Int) -> [Dlc] {
        entries.filter { $0.gameCode == gameCode && $0.type == type && $0.index == index }
    }

    func dlcs(gameCode: String, type: String) -> [Dlc] {
        entries.filter { $0.gameCode == gameCode && $0.type == type }
    }

    func dlcs(gameCode: String) -> [Dlc] {
        entries.filter { $0.gameCode == gameCode }
    }

    func dlc(gameCode: String, type: String, name: String) -> Dlc? {
        dlcs(gameCode: gameCode, type: type).first { $0.name == name }
    }

    func index(gameCode: String, type: String, name: String) -> Int {
        dlc(gameCode: gameCode, type: type, name: name)?.index ?? 0
    }

    var all: [Dlc] { entries }

    // Formats the DLC list as the tab-separated wire format the DS expects in DLS responses.
    func listString(for dlcs: [Dlc]) -> String {
        dlcs.map { "\($0.name)\t\t\($0.type)\t\($0.index)\t\t\($0.projectedSize)\r\n" }.joined()
    }
}