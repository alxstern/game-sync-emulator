import SwiftUI

struct AvenueVisitorSlot: Identifiable {
    let id: Int
    var type: AvenueVisitorType?
    var name: String = ""
    var shopType: AvenueShopType = .raffle
    var gameVersion: GameVersion = .black2English
    var country: Country?
    var region: Region?
    var phrase: Int = 0
    var dreamerSpecies: PokemonSpecies?
}

// Column widths shared between the header and each row so everything lines up.
private enum AvenueColumn {
    static let icon: CGFloat = 32
    static let type: CGFloat = 150
    static let name: CGFloat = 80
    static let shop: CGFloat = 110
    static let game: CGFloat = 150
    static let country: CGFloat = 150
    static let region: CGFloat = 130
    static let phrase: CGFloat = 90
    static let species: CGFloat = 140
}

struct AvenueEditorView: View {
    @Binding var slots: [AvenueVisitorSlot]

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

            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 6) {
                    AvenueHeaderRow()

                    ForEach($slots) { slotBinding in
                        AvenueVisitorRow(slot: slotBinding, availableSpecies: availableSpecies, availableCountries: availableCountries)
                        Divider()
                    }
                }
                .padding(12)
            }
        }
    }
}

private struct AvenueHeaderRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Spacer().frame(width: AvenueColumn.icon)
            Text("Type").frame(width: AvenueColumn.type, alignment: .leading)
            Text("Name").frame(width: AvenueColumn.name, alignment: .leading)
            Text("Shop").frame(width: AvenueColumn.shop, alignment: .leading)
            Text("Game").frame(width: AvenueColumn.game, alignment: .leading)
            Text("Country").frame(width: AvenueColumn.country, alignment: .leading)
            Text("Region").frame(width: AvenueColumn.region, alignment: .leading)
            Text("Phrase").frame(width: AvenueColumn.phrase, alignment: .leading)
            Text("Pokémon").frame(width: AvenueColumn.species, alignment: .leading)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
    }
}

private struct AvenueVisitorRow: View {
    @Binding var slot: AvenueVisitorSlot
    let availableSpecies: [PokemonSpecies]
    let availableCountries: [Country]

    private var isJapanese: Bool { slot.gameVersion.languageCode == 1 }

    private var countryOptions: [Country] {
        guard isJapanese else { return availableCountries }
        return availableCountries.filter { $0.id == 105 } // Japanese-language visitors only appear from Japan.
    }

    private var hasSecondaryFields: Bool { slot.type != nil }

    var body: some View {
        HStack(spacing: 10) {
            iconView
                .frame(width: AvenueColumn.icon)

            Picker("", selection: $slot.type) {
                Text("—").tag(AvenueVisitorType?.none)
                ForEach(AvenueVisitorType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(AvenueVisitorType?.some(type))
                }
            }
            .labelsHidden()
            .frame(width: AvenueColumn.type, alignment: .leading)

            TextField("Name", text: $slot.name)
                .textFieldStyle(.roundedBorder)
                .frame(width: AvenueColumn.name)
                .disabled(!hasSecondaryFields)
                .onChange(of: slot.name) { _, newValue in
                    if newValue.count > 7 { slot.name = String(newValue.prefix(7)) }
                }

            Picker("", selection: $slot.shopType) {
                ForEach(AvenueShopType.allCases, id: \.self) { shop in
                    Text(shop.displayName).tag(shop)
                }
            }
            .labelsHidden()
            .frame(width: AvenueColumn.shop, alignment: .leading)
            .disabled(!hasSecondaryFields)

            Picker("", selection: $slot.gameVersion) {
                ForEach(GameVersion.allCases, id: \.self) { version in
                    Text(version.displayName).tag(version)
                }
            }
            .labelsHidden()
            .frame(width: AvenueColumn.game, alignment: .leading)
            .disabled(!hasSecondaryFields)
            .onChange(of: slot.gameVersion) { _, _ in
                if let country = slot.country, !countryOptions.contains(country) {
                    slot.country = nil
                    slot.region = nil
                }
            }

            CountrySearchPicker(selection: $slot.country, options: countryOptions)
                .frame(width: AvenueColumn.country, alignment: .leading)
                .disabled(!hasSecondaryFields)
                .onChange(of: slot.country) { _, _ in
                    slot.region = nil
                }

            Picker("", selection: $slot.region) {
                Text("—").tag(Region?.none)
                ForEach(slot.country?.regions ?? [], id: \.self) { region in
                    Text(region.name).tag(Region?.some(region))
                }
            }
            .labelsHidden()
            .frame(width: AvenueColumn.region, alignment: .leading)
            .disabled(!hasSecondaryFields || !(slot.country?.hasRegions ?? false))

            Picker("", selection: $slot.phrase) {
                ForEach(0..<8) { i in
                    Text("Phrase \(i + 1)").tag(i)
                }
            }
            .labelsHidden()
            .frame(width: AvenueColumn.phrase, alignment: .leading)
            .disabled(!hasSecondaryFields)

            SpeciesSearchPicker(selection: $slot.dreamerSpecies, options: availableSpecies)
                .frame(width: AvenueColumn.species, alignment: .leading)
                .disabled(!hasSecondaryFields)
        }
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
