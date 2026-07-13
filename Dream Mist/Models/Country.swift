struct Region: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct Country: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let regions: [Region]?

    var hasRegions: Bool { !(regions?.isEmpty ?? true) }
}
