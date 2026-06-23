import Foundation

actor PlayerManager {

    enum Failure: Error {
        case invalidGameSyncId
        case duplicateGameSyncId
        case directoryAlreadyExists
        case playerNotFound
        case missingDataDirectory
    }

    private var players: [String: Player]
    let dataDirectory: URL

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .prettyPrinted
        return e
    }()

    private let decoder = JSONDecoder()

    init(dataDirectory: URL) {
        self.dataDirectory = dataDirectory
        self.players = Self.loadPlayers(from: dataDirectory)
        print("Loaded \(players.count) player(s)")
    }

    // nonisolated static so it can be called during init before the actor is fully live.
    private nonisolated static func loadPlayers(from directory: URL) -> [String: Player] {
        var loaded: [String: Player] = [:]
        let dec = JSONDecoder()

        guard let dirs = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return loaded }

        for dir in dirs {
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            let file = dir.appendingPathComponent("data.json")
            do {
                let data = try Data(contentsOf: file)
                var player = try dec.decode(Player.self, from: data)
                guard GSIDUtility.isValid(player.gameSyncId) else {
                    print("Error: Invalid Game Sync ID '\(player.gameSyncId)' in \(file.path)")
                    continue
                }
                guard loaded[player.gameSyncId] == nil else {
                    print("Error: Duplicate Game Sync ID '\(player.gameSyncId)'")
                    continue
                }
                player.dataDirectory = file.deletingLastPathComponent()
                loaded[player.gameSyncId] = player
            } catch {
                print("Error loading player at \(file.path): \(error)")
            }
        }

        return loaded
    }

    func savePlayer(_ player: Player) throws {
        guard let dataFile = player.dataFile else { throw Failure.missingDataDirectory }
        let dir = dataFile.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try encoder.encode(player).write(to: dataFile, options: .atomic)
    }

    func savePlayers() {
        for player in players.values { try? savePlayer(player) }
    }

    func registerPlayer(gameSyncId: String, gameVersion: GameVersion) throws -> Player {
        guard GSIDUtility.isValid(gameSyncId)    else { throw Failure.invalidGameSyncId }
        guard players[gameSyncId] == nil         else { throw Failure.duplicateGameSyncId }

        let playerDir = dataDirectory.appendingPathComponent(gameSyncId)
        guard !FileManager.default.fileExists(atPath: playerDir.path) else { throw Failure.directoryAlreadyExists }

        let player = Player(gameSyncId: gameSyncId, gameVersion: gameVersion, dataDirectory: playerDir)
        try savePlayer(player)
        players[gameSyncId] = player
        return player
    }

    // Call this after a handler modifies a player's state to persist the change.
    func updatePlayer(_ player: Player) throws {
        guard players[player.gameSyncId] != nil else { throw Failure.playerNotFound }
        players[player.gameSyncId] = player
        try savePlayer(player)
    }

    func storeSaveData(_ data: Data, for gameSyncId: String) throws {
        guard let saveFile = players[gameSyncId]?.saveFile else { throw Failure.playerNotFound }
        try data.write(to: saveFile, options: .atomic)
    }

    func player(gameSyncId: String) -> Player?   { players[gameSyncId] }
    func playerExists(gameSyncId: String) -> Bool { players[gameSyncId] != nil }
    var allPlayers: [Player]                     { Array(players.values) }
}