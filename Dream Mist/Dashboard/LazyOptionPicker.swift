import SwiftUI

// Like a native Picker, but the option list is only built when the popover is actually opened.
// Native macOS Pickers construct every menu item eagerly, which is fine for a handful of rows
// but adds up fast when repeated per-row in a table (e.g. 12 Join Avenue rows x 28 GameVersion
// options = 336 menu items built up front just for that one column).
struct LazyOptionPicker<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> String

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Text(label(selection))
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
            List(options, id: \.self) { option in
                Button {
                    selection = option
                    isPresented = false
                } label: {
                    Text(label(option))
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .frame(width: 220, height: 300)
        }
    }
}
