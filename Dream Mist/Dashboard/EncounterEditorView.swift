import SwiftUI

struct EncounterSlot: Identifiable {
    let id = UUID()
    var species: PokemonSpecies? = nil
    var gender: PokemonGender = .male
    var dreamAnimation: DreamAnimation = .lookAround
}

struct EncounterEditorView: View {
    let gameVersion: GameVersion?
    @Binding var slots: [EncounterSlot]

    private static let maxSlots = 10
    private var availableSpecies: [PokemonSpecies] { GameData.downloadableSpecies(for: gameVersion) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Up to 10 Entree Forest encounters. Unova Pokémon require a Black 2 / White 2 save.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 10)

            Divider()

            List {
                ForEach($slots) { slotBinding in
                    EncounterRow(slot: slotBinding, availableSpecies: availableSpecies) {
                        slots.removeAll { $0.id == slotBinding.id }
                    }
                }
            }
            .listStyle(.inset)

            if slots.count < Self.maxSlots {
                Divider()
                Button {
                    slots.append(EncounterSlot())
                } label: {
                    Label("Add Encounter", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(10)
            }
        }
    }
}

private struct EncounterRow: View {
    @Binding var slot: EncounterSlot
    let availableSpecies: [PokemonSpecies]
    let onRemove: () -> Void

    private var genderOptions: [PokemonGender] {
        slot.species?.genders ?? []
    }

    // Fixed column width keeps the pickers aligned across rows regardless of how wide a given
    // sprite is; height is left unconstrained so taller sprites (e.g. Lugia) get a taller row
    // instead of being squashed to match everything else.
    private static let spriteColumnWidth: CGFloat = 72

    var body: some View {
        HStack(spacing: 10) {
            spriteView
                .frame(width: Self.spriteColumnWidth)
                .padding(.vertical, 6)

            SpeciesSearchPicker(selection: $slot.species, options: availableSpecies)
                .frame(minWidth: 130, maxWidth: .infinity, alignment: .leading)
                .onChange(of: slot.species) { _, newSpecies in
                    if let genders = newSpecies?.genders, !genders.contains(slot.gender) {
                        slot.gender = genders[0]
                    }
                }

            Picker("", selection: $slot.gender) {
                ForEach(genderOptions.isEmpty ? [slot.gender] : genderOptions, id: \.self) { gender in
                    Text(gender.symbol ?? "—").tag(gender)
                }
            }
            .labelsHidden()
            .frame(width: 48)
            .disabled(genderOptions.count < 2)

            Picker("", selection: $slot.dreamAnimation) {
                ForEach(DreamAnimation.allCases, id: \.self) { animation in
                    Text(animation.displayName).tag(animation)
                }
            }
            .labelsHidden()
            .frame(minWidth: 110, idealWidth: 160, maxWidth: 200, alignment: .leading)
            .disabled(slot.species == nil)

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var spriteView: some View {
        if let species = slot.species,
           let sprite = PokemonSprite.image(species: species, form: 0, gender: slot.gender, shiny: false) {
            AnimatedImage(image: sprite, sizing: .scale(AnimatedImage.standardSpriteScale))
        } else {
            Circle().fill(.quaternary).frame(width: 36, height: 36)
        }
    }
}
