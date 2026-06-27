import Foundation

struct Player: Codable {
    let gameSyncId: String
    var gameVersion: GameVersion?
    var status: PlayerStatus
    var dreamerInfo: PokemonInfo?
    var cgearSkin: String?
    var dexSkin: String?
    var musical: String?
    var customCGearSkin: String?
    var customDexSkin: String?
    var customMusical: String?
    var levelsGained: Int
    var encounters: [DreamEncounter]
    var items: [DreamItem]
    var avenueVisitors: [AvenueVisitor]
    var decor: [DreamDecor]

    // Not persisted to JSON — set by PlayerManager when loading from disk.
    var dataDirectory: URL?

    enum CodingKeys: String, CodingKey {
        case gameSyncId, gameVersion, status, dreamerInfo
        case cgearSkin, dexSkin, musical
        case customCGearSkin, customDexSkin, customMusical
        case levelsGained, encounters, items, avenueVisitors, decor
    }

    mutating func resetDreamInfo() {
        status = .awake
        dreamerInfo = nil
        encounters = []
        items = []
        avenueVisitors = []
        decor = DreamDecor.defaultDecor
        levelsGained = 0
        cgearSkin = nil
        dexSkin = nil
        musical = nil
    }

    // Max sizes enforced by the Dream World protocol.
    mutating func setEncounters(_ new: [DreamEncounter])    { if new.count <= 10 { encounters    = new } }
    mutating func setItems(_ new: [DreamItem])              { if new.count <= 20 { items         = new } }
    mutating func setAvenueVisitors(_ new: [AvenueVisitor]) { if new.count <= 12 { avenueVisitors = new } }
    mutating func setDecor(_ new: [DreamDecor])             { if new.count <= 5  { decor         = new } }

    nonisolated var dataFile: URL?    { dataDirectory?.appendingPathComponent("data.json") }
    nonisolated var saveFile: URL?    { dataDirectory?.appendingPathComponent("save.bin") }
    nonisolated var cgearFile: URL?   { dataDirectory?.appendingPathComponent("cgear.bin") }
    nonisolated var dexFile: URL?     { dataDirectory?.appendingPathComponent("zukan.bin") }
    nonisolated var musicalFile: URL? { dataDirectory?.appendingPathComponent("musical.bin") }
}

extension Player {
    nonisolated init(gameSyncId: String, gameVersion: GameVersion? = nil, dataDirectory: URL? = nil) {
        self.gameSyncId       = gameSyncId
        self.gameVersion      = gameVersion
        self.status           = .awake
        self.dreamerInfo      = nil
        self.cgearSkin        = nil
        self.dexSkin          = nil
        self.musical          = nil
        self.customCGearSkin  = nil
        self.customDexSkin    = nil
        self.customMusical    = nil
        self.levelsGained     = 0
        self.encounters       = []
        self.items            = []
        self.avenueVisitors   = []
        self.decor            = DreamDecor.defaultDecor
        self.dataDirectory    = dataDirectory
    }
}

// Collections default to empty (or default decor) when absent in older save files.
// Both methods are nonisolated so Player can be encoded/decoded from any concurrency context.
extension Player {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(gameSyncId,      forKey: .gameSyncId)
        try c.encodeIfPresent(gameVersion, forKey: .gameVersion)
        try c.encode(status,          forKey: .status)
        try c.encodeIfPresent(dreamerInfo,     forKey: .dreamerInfo)
        try c.encodeIfPresent(cgearSkin,       forKey: .cgearSkin)
        try c.encodeIfPresent(dexSkin,         forKey: .dexSkin)
        try c.encodeIfPresent(musical,         forKey: .musical)
        try c.encodeIfPresent(customCGearSkin, forKey: .customCGearSkin)
        try c.encodeIfPresent(customDexSkin,   forKey: .customDexSkin)
        try c.encodeIfPresent(customMusical,   forKey: .customMusical)
        try c.encode(levelsGained,    forKey: .levelsGained)
        try c.encode(encounters,      forKey: .encounters)
        try c.encode(items,           forKey: .items)
        try c.encode(avenueVisitors,  forKey: .avenueVisitors)
        try c.encode(decor,           forKey: .decor)
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gameSyncId      = try c.decode(String.self,              forKey: .gameSyncId)
        gameVersion     = try c.decodeIfPresent(GameVersion.self, forKey: .gameVersion)
        status          = try c.decodeIfPresent(PlayerStatus.self,  forKey: .status)        ?? .awake
        dreamerInfo     = try c.decodeIfPresent(PokemonInfo.self,   forKey: .dreamerInfo)
        cgearSkin       = try c.decodeIfPresent(String.self,        forKey: .cgearSkin)
        dexSkin         = try c.decodeIfPresent(String.self,        forKey: .dexSkin)
        musical         = try c.decodeIfPresent(String.self,        forKey: .musical)
        customCGearSkin = try c.decodeIfPresent(String.self,        forKey: .customCGearSkin)
        customDexSkin   = try c.decodeIfPresent(String.self,        forKey: .customDexSkin)
        customMusical   = try c.decodeIfPresent(String.self,        forKey: .customMusical)
        levelsGained    = try c.decodeIfPresent(Int.self,           forKey: .levelsGained)  ?? 0
        encounters      = try c.decodeIfPresent([DreamEncounter].self, forKey: .encounters)  ?? []
        items           = try c.decodeIfPresent([DreamItem].self,      forKey: .items)       ?? []
        avenueVisitors  = try c.decodeIfPresent([AvenueVisitor].self,  forKey: .avenueVisitors) ?? []
        if let savedDecor = try c.decodeIfPresent([DreamDecor].self, forKey: .decor) {
            decor = savedDecor
        } else {
            decor = DreamDecor.defaultDecor
        }
        dataDirectory   = nil
    }
}