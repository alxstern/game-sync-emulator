struct DreamDecor: Codable, Equatable {
    let id: Int
    let name: String

    nonisolated static let defaultDecor: [DreamDecor] = [
        DreamDecor(id: 1, name: "Design Table"),
        DreamDecor(id: 2, name: "Design Stool"),
        DreamDecor(id: 3, name: "Flower Vase"),
        DreamDecor(id: 4, name: "Cuddle Rug"),
        DreamDecor(id: 6, name: "Wall Poster")
    ]

    nonisolated static func == (lhs: DreamDecor, rhs: DreamDecor) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}