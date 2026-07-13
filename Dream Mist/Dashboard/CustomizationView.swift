import SwiftUI

struct CustomizationView: View {
    let dlcList: DlcList
    let gameVersion: GameVersion?
    @Binding var cgearSkin: String?
    @Binding var dexSkin: String?

    // C-Gear and C-Gear 2 skins aren't interchangeable between BW and BW2 saves.
    private var cgearType: String { (gameVersion?.isVersion2 ?? true) ? "CGEAR2" : "CGEAR" }
    private var cgearOptions: [Dlc] { dlcList.dlcs(gameCode: "IRAO", type: cgearType).sorted { $0.name < $1.name } }
    private var dexOptions: [Dlc] { dlcList.dlcs(gameCode: "IRAO", type: "ZUKAN").sorted { $0.name < $1.name } }

    private var selectedCGear: Dlc? { cgearOptions.first { $0.name == cgearSkin } }
    private var selectedDex: Dlc? { dexOptions.first { $0.name == dexSkin } }

    var body: some View {
        VStack(spacing: 24) {
            HStack(alignment: .top, spacing: 24) {
                previewBox(title: "C-Gear Skin Preview", dlc: selectedCGear) {
                    TiledSkinRenderer.cgearSkin(path: $0.path, normalizeIndices: cgearType == "CGEAR")
                }
                previewBox(title: "Pokédex Skin Preview", dlc: selectedDex) {
                    TiledSkinRenderer.dexSkin(path: $0.path)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 0) {
                pickerRow(label: "C-Gear Skin") {
                    Picker("", selection: $cgearSkin) {
                        Text("Do Not Change").tag(String?.none)
                        ForEach(cgearOptions, id: \.name) { dlc in
                            Text(displayName(for: dlc)).tag(String?.some(dlc.name))
                        }
                    }
                    .labelsHidden()
                }

                Divider().padding(.leading, 16)

                pickerRow(label: "Pokédex Skin") {
                    Picker("", selection: $dexSkin) {
                        Text("Do Not Change").tag(String?.none)
                        ForEach(dexOptions, id: \.name) { dlc in
                            Text(displayName(for: dlc)).tag(String?.some(dlc.name))
                        }
                    }
                    .labelsHidden()
                }
            }
            .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 10))

            Spacer(minLength: 0)
        }
        .padding()
    }

    // Both skin types render to the full 256x192 DS screen, so there's no relative-size
    // concern here (unlike sprites/icons) — a fixed native-resolution box is correct for both.
    @ViewBuilder
    private func previewBox(title: String, dlc: Dlc?, decode: (Dlc) -> NSImage?) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)

            Group {
                if let dlc, let image = decode(dlc) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                } else {
                    ContentUnavailableView(
                        "No Preview",
                        systemImage: "photo",
                        description: Text("Choose a skin to preview it here.")
                    )
                }
            }
            .frame(width: 256, height: 192)
            .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func pickerRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
            Spacer()
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func displayName(for dlc: Dlc) -> String {
        let noExtension = (dlc.name as NSString).deletingPathExtension
        return noExtension.replacingOccurrences(of: "[PPorg]", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
