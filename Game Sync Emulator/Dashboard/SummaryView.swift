import SwiftUI

struct SummaryView: View {
    let player: Player

    var body: some View {
        if let info = player.dreamerInfo {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    Group {
                        if let sprite = PokemonSprite.image(for: info) {
                            AnimatedImage(image: sprite, sizing: .scale(AnimatedImage.standardSpriteScale))
                        } else {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 72, height: 72)
                    .background(.quaternary, in: .circle)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(info.nickname)
                                .font(.title2.bold())
                            if let symbol = info.gender.symbol {
                                Text(symbol)
                                    .font(.title3.bold())
                                    .foregroundStyle(info.gender == .male ? .blue : .pink)
                            }
                            Text("Lv. \(info.level)")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(info.nature.displayName) · \(GameData.abilityName(info.ability))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        if info.heldItem != 0 {
                            Label(GameData.itemName(info.heldItem), systemImage: "bag.fill")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 12))

                HStack {
                    Label(info.trainerName, systemImage: "person.fill")
                    Spacer()
                    Text("ID No. \(String(format: "%05d", info.trainerId))")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

                Spacer()
            }
            .padding()
        } else {
            ContentUnavailableView(
                "No Pokémon Tucked In",
                systemImage: "moon.zzz",
                description: Text("Use Game Sync in-game to tuck in a Pokémon first.")
            )
        }
    }
}

private func previewPlayer(species: Int, shiny: Bool, female: Bool) -> Player {
    var player = Player(gameSyncId: "ABCDEFGHIJ")
    // A shiny personality/IV combo isn't worth reproducing exactly for a preview —
    // PokemonInfo.isShiny is derived from these, so fake values that satisfy it are enough.
    player.dreamerInfo = PokemonInfo(
        nickname: "Sparky",
        trainerName: "Ash",
        nature: .jolly,
        gender: female ? .female : .male,
        species: species,
        personality: shiny ? 0 : 16,
        trainerId: 0,
        trainerSecretId: 0,
        level: 25,
        form: 0,
        ability: 9,
        heldItem: 0
    )
    return player
}

#Preview("Normal") {
    SummaryView(player: previewPlayer(species: 25, shiny: false, female: false)) // Pikachu
}

#Preview("Shiny Female") {
    SummaryView(player: previewPlayer(species: 3, shiny: true, female: true)) // Venusaur
}
