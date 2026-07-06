import SwiftUI

struct EncounterSlot: Identifiable {
    let id: Int
    var species: PokemonSpecies?
    var gender: PokemonGender = .male
    var dreamAnimation: DreamAnimation = .lookAround
}

struct EncounterEditorView: View {
    let gameVersion: GameVersion?
    @Binding var slots: [EncounterSlot]

    private var availableSpecies: [PokemonSpecies] { GameData.downloadableSpecies(for: gameVersion) }

    var body: some View {
        Form {
            Section {
                Text("Set up to 10 Entree Forest encounters. Unova Pokémon require a Black 2 / White 2 save.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach($slots) { slotBinding in
                let slot = slotBinding.wrappedValue

                Section("Encounter \(slot.id + 1)") {
                    Picker("Species", selection: slotBinding.species) {
                        Text("None").tag(PokemonSpecies?.none)
                        ForEach(availableSpecies) { species in
                            Text(species.name).tag(Optional(species))
                        }
                    }
                    .onChange(of: slot.species) { _, newSpecies in
                        if let genders = newSpecies?.genders, !genders.contains(slot.gender) {
                            slotBinding.gender.wrappedValue = genders[0]
                        }
                    }

                    if let species = slot.species {
                        if species.genders.count > 1 {
                            Picker("Gender", selection: slotBinding.gender) {
                                ForEach(species.genders, id: \.self) { gender in
                                    Text(gender.displayName).tag(gender)
                                }
                            }
                        }
                        Picker("Animation", selection: slotBinding.dreamAnimation) {
                            ForEach(DreamAnimation.allCases, id: \.self) { animation in
                                Text(animation.displayName).tag(animation)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
