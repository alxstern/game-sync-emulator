import SwiftUI

// Same searchable-popover pattern as SpeciesSearchPicker/ItemSearchPicker, for the ~130-entry
// country list.
struct CountrySearchPicker: View {
    @Binding var selection: Country?
    let options: [Country]

    @State private var isPresented = false
    @State private var searchText = ""

    private var filteredOptions: [Country] {
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

                    ForEach(filteredOptions) { country in
                        Button {
                            selection = country
                            isPresented = false
                        } label: {
                            Text(country.name)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
            .frame(width: 220, height: 320)
            .onAppear { searchText = "" }
        }
    }
}
