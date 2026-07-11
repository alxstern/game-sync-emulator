import SwiftUI

struct DashboardContentView: View {
    let playerManager: PlayerManager
    let player: Player
    let onLogOut: () -> Void

    @State private var encounterSlots: [EncounterSlot]
    @State private var itemSlots: [ItemSlot]
    @State private var avenueSlots: [AvenueVisitorSlot]
    @State private var selectedSection: PanelSection? = .summary
    @State private var statusMessage: String?

    enum PanelSection: String, CaseIterable, Identifiable {
        case summary = "Summary"
        case encounters = "Entree Forest"
        case items = "Dream Remnants"
        case avenue = "Join Avenue"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .summary: "person.crop.circle"
            case .encounters: "leaf"
            case .items: "bag.fill"
            case .avenue: "storefront.fill"
            }
        }
    }

    init(playerManager: PlayerManager, player: Player, onLogOut: @escaping () -> Void) {
        self.playerManager = playerManager
        self.player = player
        self.onLogOut = onLogOut
        _encounterSlots = State(initialValue: Self.makeSlots(from: player))
        _itemSlots = State(initialValue: Self.makeItemSlots(from: player))
        _avenueSlots = State(initialValue: Self.makeAvenueSlots(from: player))
    }

    // Join Avenue only exists in Black 2 / White 2 — the server drops it entirely for BW1 players.
    private var availableSections: [PanelSection] {
        PanelSection.allCases.filter { $0 != .avenue || (player.gameVersion?.isVersion2 ?? true) }
    }

    var body: some View {
        NavigationSplitView {
            List(availableSections, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon).tag(section)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            VStack(spacing: 0) {
                switch selectedSection {
                case .summary, .none:
                    SummaryView(player: player)
                case .encounters:
                    EncounterEditorView(gameVersion: player.gameVersion, slots: $encounterSlots)
                case .items:
                    ItemsEditorView(slots: $itemSlots)
                case .avenue:
                    AvenueEditorView(slots: $avenueSlots)
                }

                Divider()

                HStack {
                    Text("\(player.gameVersion?.displayName ?? "Unknown Version") · \(player.gameSyncId)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Log Out", action: onLogOut)
                    Button("Save Profile", action: save)
                        .buttonStyle(.borderedProminent)
                }
                .padding(12)
            }
        }
        .alert("Attention", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("OK") { statusMessage = nil }
        } message: {
            Text(statusMessage ?? "")
        }
    }

    private func save() {
        var updated = player
        updated.setEncounters(encounterSlots.compactMap { slot in
            guard let species = slot.species else { return nil }
            return DreamEncounter(species: species.id, move: 0, form: 0, gender: slot.gender, animation: slot.dreamAnimation)
        })
        updated.setItems(itemSlots.compactMap { slot in
            guard let item = slot.item else { return nil }
            return DreamItem(id: item.id, quantity: slot.quantity)
        })
        updated.setAvenueVisitors(avenueSlots.compactMap { slot in
            guard let type = slot.type, !slot.name.isEmpty,
                  let country = slot.country, let dreamer = slot.dreamerSpecies else { return nil }
            return AvenueVisitor(
                name: slot.name,
                type: type,
                shopType: slot.shopType,
                gameVersion: slot.gameVersion,
                countryCode: country.id,
                stateProvinceCode: slot.region?.id ?? 0,
                personality: slot.phrase,
                dreamerSpecies: dreamer.id
            )
        })
        updated.status = .wakeReady

        Task {
            do {
                try await playerManager.updatePlayer(updated)
                statusMessage = "Profile saved! Use Game Sync to wake up your Pokémon and download your selected content."
            } catch {
                statusMessage = "Failed to save profile: \(error.localizedDescription)"
            }
        }
    }

    private static func makeSlots(from player: Player) -> [EncounterSlot] {
        var slots = (0..<10).map { EncounterSlot(id: $0) }
        for (index, encounter) in player.encounters.enumerated() where index < 10 {
            slots[index].species = GameData.species[encounter.species]
            slots[index].gender = encounter.gender
            slots[index].dreamAnimation = encounter.animation
        }
        return slots
    }

    private static func makeItemSlots(from player: Player) -> [ItemSlot] {
        let allItems = Dictionary(uniqueKeysWithValues: GameData.allItems().map { ($0.id, $0) })
        var slots = (0..<20).map { ItemSlot(id: $0) }
        for (index, item) in player.items.enumerated() where index < 20 {
            slots[index].item = allItems[item.id]
            slots[index].quantity = item.quantity
        }
        return slots
    }

    private static func makeAvenueSlots(from player: Player) -> [AvenueVisitorSlot] {
        var slots = (0..<12).map { AvenueVisitorSlot(id: $0) }
        for (index, visitor) in player.avenueVisitors.enumerated() where index < 12 {
            let country = GameData.country(visitor.countryCode)
            slots[index].type = visitor.type
            slots[index].name = visitor.name
            slots[index].shopType = visitor.shopType
            slots[index].gameVersion = visitor.gameVersion
            slots[index].country = country
            slots[index].region = country?.regions?.first { $0.id == visitor.stateProvinceCode }
            slots[index].phrase = visitor.personality
            slots[index].dreamerSpecies = GameData.species[visitor.dreamerSpecies]
        }
        return slots
    }
}
