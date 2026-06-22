import Testing
import Foundation
@testable import Game_Sync_Emulator

@Suite("Player")
struct PlayerTests {

    private func makePlayer() throws -> Player {
        let json = #"{"gameSyncId":"VFWM2QAXNF","gameVersion":"BLACK_ENGLISH"}"#.data(using: .utf8)!
        return try JSONDecoder().decode(Player.self, from: json)
    }

    // MARK: Codable round-trip

    @Test func roundTripsViaJSON() throws {
        var player = try makePlayer()
        player.status = .dreaming
        player.levelsGained = 3
        player.cgearSkin = "custom_skin"
        player.encounters = [
            DreamEncounter(species: 25, move: 141, form: 0, gender: .male, animation: .lookAround)
        ]
        player.items = [DreamItem(id: 1, quantity: 2)]

        let encoded = try JSONEncoder().encode(player)
        let decoded = try JSONDecoder().decode(Player.self, from: encoded)

        #expect(decoded.gameSyncId          == "VFWM2QAXNF")
        #expect(decoded.gameVersion         == .blackEnglish)
        #expect(decoded.status              == .dreaming)
        #expect(decoded.levelsGained        == 3)
        #expect(decoded.cgearSkin           == "custom_skin")
        #expect(decoded.encounters.count    == 1)
        #expect(decoded.encounters[0].species == 25)
        #expect(decoded.items               == [DreamItem(id: 1, quantity: 2)])
        #expect(decoded.dataDirectory       == nil)  // never serialized
    }

    // MARK: Default values when fields are absent from JSON

    @Test func defaultsWhenFieldsAbsent() throws {
        let player = try makePlayer()

        #expect(player.status         == .awake)
        #expect(player.levelsGained   == 0)
        #expect(player.encounters     == [])
        #expect(player.items          == [])
        #expect(player.avenueVisitors.isEmpty)
        #expect(player.decor          == DreamDecor.defaultDecor)
        #expect(player.dreamerInfo    == nil)
        #expect(player.cgearSkin      == nil)
        #expect(player.dataDirectory  == nil)
    }

    // MARK: resetDreamInfo

    @Test func resetClearsDreamState() throws {
        var player = try makePlayer()
        player.status = .dreaming
        player.levelsGained = 5
        player.encounters = [DreamEncounter(species: 25, move: 141, form: 0, gender: .male, animation: .walkAround)]
        player.items = [DreamItem(id: 3, quantity: 1)]
        player.cgearSkin = "skin"
        player.dexSkin = "dexskin"
        player.musical = "song"
        player.decor = []

        player.resetDreamInfo()

        #expect(player.status       == .awake)
        #expect(player.levelsGained == 0)
        #expect(player.encounters   == [])
        #expect(player.items        == [])
        #expect(player.cgearSkin    == nil)
        #expect(player.dexSkin      == nil)
        #expect(player.musical      == nil)
        #expect(player.dreamerInfo  == nil)
        #expect(player.decor        == DreamDecor.defaultDecor)
    }

    // MARK: Max-size enforcement

    @Test func enforcesEncounterLimit() throws {
        var player = try makePlayer()
        let ten    = (1...10).map { DreamEncounter(species: $0, move: 0, form: 0, gender: .genderless, animation: .lookAround) }
        let eleven = ten + [DreamEncounter(species: 999, move: 0, form: 0, gender: .genderless, animation: .lookAround)]

        player.setEncounters(ten)
        #expect(player.encounters.count == 10)

        player.setEncounters(eleven)
        #expect(player.encounters.count == 10)  // rejected — still 10
    }

    @Test func enforcesItemLimit() throws {
        var player = try makePlayer()
        let twenty    = (0..<20).map { DreamItem(id: $0, quantity: 1) }
        let twentyOne = twenty + [DreamItem(id: 999, quantity: 1)]

        player.setItems(twenty)
        #expect(player.items.count == 20)

        player.setItems(twentyOne)
        #expect(player.items.count == 20)  // rejected
    }

    @Test func enforcesDecorLimit() throws {
        var player = try makePlayer()
        let five = (0..<5).map { DreamDecor(id: $0, name: "Decor \($0)") }
        let six  = five + [DreamDecor(id: 999, name: "Extra")]

        player.setDecor(five)
        #expect(player.decor.count == 5)

        player.setDecor(six)
        #expect(player.decor.count == 5)  // rejected
    }

    @Test func enforcesAvenueVisitorLimit() throws {
        var player = try makePlayer()
        let visitor = AvenueVisitor(
            name: "Red", type: .youngster, shopType: .raffle,
            gameVersion: .blackEnglish, countryCode: 1,
            stateProvinceCode: 0, personality: 0, dreamerSpecies: 25
        )
        let twelve   = Array(repeating: visitor, count: 12)
        let thirteen = Array(repeating: visitor, count: 13)

        player.setAvenueVisitors(twelve)
        #expect(player.avenueVisitors.count == 12)

        player.setAvenueVisitors(thirteen)
        #expect(player.avenueVisitors.count == 12)  // rejected
    }
}