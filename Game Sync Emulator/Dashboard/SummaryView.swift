import SwiftUI

struct SummaryView: View {
    let player: Player

    var body: some View {
        if let info = player.dreamerInfo {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Group {
                            if let sprite = PokemonSprite.image(for: info) {
                                Image(nsImage: sprite)
                                    .resizable()
                                    .interpolation(.none)
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background(.quaternary, in: .circle)
                        VStack(alignment: .leading) {
                            Text(info.nickname)
                                .font(.title3.bold())
                            Text("Tucked in and dreaming")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Trainer") {
                    LabeledContent("OT", value: info.trainerName)
                    LabeledContent("ID No.", value: String(format: "%05d", info.trainerId))
                    LabeledContent("SID No.", value: String(format: "%05d", info.trainerSecretId))
                    LabeledContent("PID", value: String(format: "%08X", info.personality))
                }
                Section("Pokémon") {
                    LabeledContent("Ability", value: GameData.abilityName(info.ability))
                    LabeledContent("Nature", value: info.nature.displayName)
                    LabeledContent("Gender", value: info.gender.displayName)
                    LabeledContent("Level", value: "\(info.level)")
                    LabeledContent("Held Item", value: info.heldItem == 0 ? "None" : GameData.itemName(info.heldItem))
                }
            }
            .formStyle(.grouped)
        } else {
            ContentUnavailableView(
                "No Pokémon Tucked In",
                systemImage: "moon.zzz",
                description: Text("Use Game Sync in-game to tuck in a Pokémon first.")
            )
        }
    }
}
