import SwiftUI

// A button that opens a searchable popover instead of a plain Picker — scrolling through
// 600+ species alphabetically/by dex order to find one is painful without a filter.
struct SpeciesSearchPicker: View {
    @Binding var selection: PokemonSpecies?
    let options: [PokemonSpecies]

    @State private var isPresented = false
    @State private var searchText = ""

    private var filteredOptions: [PokemonSpecies] {
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

                    ForEach(filteredOptions) { species in
                        Button {
                            selection = species
                            isPresented = false
                        } label: {
                            HStack {
                                Text("#\(species.id)")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 40, alignment: .leading)
                                Text(species.name)
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
}
