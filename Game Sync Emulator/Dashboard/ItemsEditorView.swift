import SwiftUI

struct ItemSlot: Identifiable {
    let id: Int
    var item: ItemOption?
    var quantity: Int = 1
}

struct ItemsEditorView: View {
    @Binding var slots: [ItemSlot]

    private let availableItems = GameData.allItems()
    private let columns = [GridItem(.adaptive(minimum: 260, maximum: 320), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Up to 20 Dream Remnants. Talk to the boy near the Entree Forest entrance after waking up to receive them.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 10)

            Divider()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach($slots) { slotBinding in
                        ItemCell(slot: slotBinding, availableItems: availableItems)
                    }
                }
                .padding(12)
            }
        }
    }
}

private struct ItemCell: View {
    @Binding var slot: ItemSlot
    let availableItems: [ItemOption]

    var body: some View {
        HStack(spacing: 8) {
            iconView
                .frame(width: 24)

            ItemSearchPicker(selection: $slot.item, options: availableItems)
                .frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)
                .onChange(of: slot.item) { _, newItem in
                    if newItem == nil { slot.quantity = 1 }
                }

            Stepper(value: $slot.quantity, in: 1...20) {
                Text("×\(slot.quantity)")
                    .monospacedDigit()
            }
            .fixedSize()
            .disabled(slot.item == nil)
        }
        .padding(8)
        .background(.quaternary.opacity(0.2), in: .rect(cornerRadius: 8))
    }

    @ViewBuilder
    private var iconView: some View {
        if let item = slot.item, let icon = ItemSprite.image(for: item.id) {
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
