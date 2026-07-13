import SwiftUI

// Same searchable-popover pattern as SpeciesSearchPicker, for the 619-entry item list.
struct ItemSearchPicker: View {
    @Binding var selection: ItemOption?
    let options: [ItemOption]

    @State private var isPresented = false
    @State private var searchText = ""

    private var filteredOptions: [ItemOption] {
        guard !searchText.isEmpty else { return options }
        return options.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Text(selection?.name ?? "—")
                    .foregroundStyle(selection == nil ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 5))
        .popover(isPresented: $isPresented) {
            VStack(spacing: 0) {
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .padding(8)
                Divider()
                List {
                    Button {
                        selection = nil
                        isPresented = false
                    } label: {
                        Text("None").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    ForEach(filteredOptions) { item in
                        Button {
                            selection = item
                            isPresented = false
                        } label: {
                            HStack {
                                iconView(for: item)
                                    .frame(width: 20)
                                Text(item.name)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
            .frame(width: 240, height: 320)
            .onAppear { searchText = "" }
        }
    }

    @ViewBuilder
    private func iconView(for item: ItemOption) -> some View {
        if let icon = ItemSprite.image(for: item.id) {
            Image(nsImage: icon)
                .resizable()
                .frame(
                    width: icon.size.width * AnimatedImage.standardSpriteScale,
                    height: icon.size.height * AnimatedImage.standardSpriteScale
                )
        } else {
            Color.clear
        }
    }
}
