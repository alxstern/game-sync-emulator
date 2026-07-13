struct DreamItem: Codable, Equatable {
    let id: Int
    let quantity: Int

    nonisolated static func == (lhs: DreamItem, rhs: DreamItem) -> Bool {
        lhs.id == rhs.id && lhs.quantity == rhs.quantity
    }
}