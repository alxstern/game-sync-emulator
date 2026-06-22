enum AvenueShopType: String, Codable {
    case raffle  = "RAFFLE"
    case florist = "FLORIST"
    case salon   = "SALON"
    case antique = "ANTIQUE"
    case dojo    = "DOJO"
    case cafe    = "CAFE"
    case market  = "MARKET"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AvenueShopType(rawValue: raw) ?? .raffle
    }

    var displayName: String {
        switch self {
        case .raffle:  return "Raffle Shop"
        case .florist: return "Flower Shop"
        case .salon:   return "Beauty Salon"
        case .antique: return "Antique Shop"
        case .dojo:    return "Dojo"
        case .cafe:    return "Café"
        case .market:  return "Market"
        }
    }
}