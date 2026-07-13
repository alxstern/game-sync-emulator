import SwiftUI

struct AvenueVisitorSlot: Identifiable {
    let id = UUID()
    var type: AvenueVisitorType? = nil
    var name: String = ""
    var shopType: AvenueShopType = .raffle
    var gameVersion: GameVersion = .black2English
    var country: Country? = nil
    var region: Region? = nil
    var phrase: Int = 0
    var dreamerSpecies: PokemonSpecies? = nil
}

struct AvenueEditorView: View {
    @Binding var slots: [AvenueVisitorSlot]

    private static let maxSlots = 12
    private let availableSpecies = GameData.allSpecies()
    private let availableCountries = GameData.allCountries()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Up to 12 Join Avenue visitors. New visitors won't appear if the avenue already has the maximum amount.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 10)

            Divider()

            // Vertical-only scrolling — each row wraps its fields onto a second line instead of
            // extending horizontally, so the section never needs to scroll sideways.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach($slots) { slotBinding in
                        AvenueVisitorRow(slot: slotBinding, availableSpecies: availableSpecies, availableCountries: availableCountries) {
                            slots.removeAll { $0.id == slotBinding.id }
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if slots.count < Self.maxSlots {
                Divider()
                Button {
                    slots.append(AvenueVisitorSlot())
                } label: {
                    Label("Add Visitor", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(10)
            }
        }
    }
}

// Small caption above a control, since the compact custom pickers (LazyOptionPicker,
// CountrySearchPicker, SpeciesSearchPicker) don't show a title the way a native Picker does.
private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            content
        }
    }
}

private struct AvenueVisitorRow: View {
    @Binding var slot: AvenueVisitorSlot
    let availableSpecies: [PokemonSpecies]
    let availableCountries: [Country]
    let onRemove: () -> Void

    private var isJapanese: Bool { slot.gameVersion.languageCode == 1 }

    private var countryOptions: [Country] {
        guard isJapanese else { return availableCountries }
        return availableCountries.filter { $0.id == 105 } // Japanese-language visitors only appear from Japan.
    }

    private var hasSecondaryFields: Bool { slot.type != nil }

    private static let typeOptions: [AvenueVisitorType?] = [nil] + AvenueVisitorType.allCases.map { $0 as AvenueVisitorType? }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                iconView
                    .frame(width: 28)

                LabeledField(label: "Type") {
                    LazyOptionPicker(selection: $slot.type, options: Self.typeOptions) { $0?.displayName ?? "—" }
                        .frame(width: 150, alignment: .leading)
                }

                LabeledField(label: "Name") {
                    TextField("Name", text: $slot.name)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                        .disabled(!hasSecondaryFields)
                        .onChange(of: slot.name) { _, newValue in
                            if newValue.count > 7 { slot.name = String(newValue.prefix(7)) }
                        }
                }

                LabeledField(label: "Shop") {
                    Picker("", selection: $slot.shopType) {
                        ForEach(AvenueShopType.allCases, id: \.self) { shop in
                            Text(shop.displayName).tag(shop)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 110, alignment: .leading)
                    .disabled(!hasSecondaryFields)
                }

                Spacer(minLength: 0)

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                // Aligns the second line under the fields, past the icon column.
                Spacer().frame(width: 28)

                LabeledField(label: "Game") {
                    LazyOptionPicker(selection: $slot.gameVersion, options: GameVersion.allCases) { $0.displayName }
                        .frame(width: 150, alignment: .leading)
                        .disabled(!hasSecondaryFields)
                        .onChange(of: slot.gameVersion) { _, _ in
                            if let country = slot.country, !countryOptions.contains(country) {
                                slot.country = nil
                                slot.region = nil
                            }
                        }
                }

                LabeledField(label: "Country") {
                    CountrySearchPicker(selection: $slot.country, options: countryOptions)
                        .frame(width: 150, alignment: .leading)
                        .disabled(!hasSecondaryFields)
                        .onChange(of: slot.country) { _, _ in
                            slot.region = nil
                        }
                }

                LabeledField(label: "Region") {
                    Picker("", selection: $slot.region) {
                        Text("—").tag(Region?.none)
                        ForEach(slot.country?.regions ?? [], id: \.self) { region in
                            Text(region.name).tag(Region?.some(region))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130, alignment: .leading)
                    .disabled(!hasSecondaryFields || !(slot.country?.hasRegions ?? false))
                }

                LabeledField(label: "Phrase") {
                    Picker("", selection: $slot.phrase) {
                        ForEach(0..<8) { i in
                            Text("Phrase \(i + 1)").tag(i)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 90, alignment: .leading)
                    .disabled(!hasSecondaryFields)
                }

                LabeledField(label: "Pokémon") {
                    SpeciesSearchPicker(selection: $slot.dreamerSpecies, options: availableSpecies)
                        .frame(width: 140, alignment: .leading)
                        .disabled(!hasSecondaryFields)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.2), in: .rect(cornerRadius: 8))
    }

    @ViewBuilder
    private var iconView: some View {
        if let type = slot.type, let icon = AvenueVisitorSprite.image(for: type) {
            Image(nsImage: icon)
                .resizable()
                .frame(
                    width: icon.size.width * AnimatedImage.standardSpriteScale,
                    height: icon.size.height * AnimatedImage.standardSpriteScale
                )
        } else {
            Circle().fill(.quaternary).frame(width: 20, height: 20)
        }
    }
}
