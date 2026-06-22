struct AvenueVisitor: Codable {
    let name: String
    let type: AvenueVisitorType
    let shopType: AvenueShopType
    let gameVersion: GameVersion
    let countryCode: Int
    let stateProvinceCode: Int
    let personality: Int
    let dreamerSpecies: Int
}