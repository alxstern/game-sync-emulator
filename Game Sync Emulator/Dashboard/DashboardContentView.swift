import SwiftUI

struct DashboardContentView: View {
    let playerManager: PlayerManager
    let player: Player
    let onLogOut: () -> Void

    @State private var encounterSlots: [EncounterSlot]
    @State private var selectedSection: PanelSection? = .summary
    @State private var statusMessage: String?

    enum PanelSection: String, CaseIterable, Identifiable {
        case summary = "Summary"
        case encounters = "Entree Forest"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .summary: "person.crop.circle"
            case .encounters: "leaf"
            }
        }
    }

    init(playerManager: PlayerManager, player: Player, onLogOut: @escaping () -> Void) {
        self.playerManager = playerManager
        self.player = player
        self.onLogOut = onLogOut
        _encounterSlots = State(initialValue: Self.makeSlots(from: player))
    }

    var body: some View {
        NavigationSplitView {
            List(PanelSection.allCases, selection: $selectedSection) { section in
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
}
