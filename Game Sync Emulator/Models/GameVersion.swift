enum GameVersion: String, Codable, CaseIterable {

    // Black & White
    case blackJapanese = "BLACK_JAPANESE"
    case blackEnglish  = "BLACK_ENGLISH"
    case blackFrench   = "BLACK_FRENCH"
    case blackItalian  = "BLACK_ITALIAN"
    case blackGerman   = "BLACK_GERMAN"
    case blackSpanish  = "BLACK_SPANISH"
    case blackKorean   = "BLACK_KOREAN"

    case whiteJapanese = "WHITE_JAPANESE"
    case whiteEnglish  = "WHITE_ENGLISH"
    case whiteFrench   = "WHITE_FRENCH"
    case whiteItalian  = "WHITE_ITALIAN"
    case whiteGerman   = "WHITE_GERMAN"
    case whiteSpanish  = "WHITE_SPANISH"
    case whiteKorean   = "WHITE_KOREAN"

    // Black 2 & White 2
    case black2Japanese = "BLACK_2_JAPANESE"
    case black2English  = "BLACK_2_ENGLISH"
    case black2French   = "BLACK_2_FRENCH"
    case black2Italian  = "BLACK_2_ITALIAN"
    case black2German   = "BLACK_2_GERMAN"
    case black2Spanish  = "BLACK_2_SPANISH"
    case black2Korean   = "BLACK_2_KOREAN"

    case white2Japanese = "WHITE_2_JAPANESE"
    case white2English  = "WHITE_2_ENGLISH"
    case white2French   = "WHITE_2_FRENCH"
    case white2Italian  = "WHITE_2_ITALIAN"
    case white2German   = "WHITE_2_GERMAN"
    case white2Spanish  = "WHITE_2_SPANISH"
    case white2Korean   = "WHITE_2_KOREAN"

    // Bitmasks for filtering which game versions a piece of content applies to.
    static let bwMask:     Int = 0b110011111111
    static let b2w2Mask:   Int = 0b001111111111
    static let allMask:    Int = bwMask | b2w2Mask
    static let japMask:    Int = 0b111100000001
    static let engMask:    Int = 0b111100000010
    static let freMask:    Int = 0b111100000100
    static let itaMask:    Int = 0b111100001000
    static let gerMask:    Int = 0b111100010000
    static let spaMask:    Int = 0b111101000000
    static let korMask:    Int = 0b111110000000
    static let japKorMask: Int = japMask | korMask
    static let naEurMask:  Int = engMask | freMask | itaMask | gerMask | spaMask

    static func lookup(serial: String) -> GameVersion? {
        bySerial[serial]
    }

    static func lookup(romCode: Int, languageCode: Int) -> GameVersion? {
        byCodes[bits(romCode: romCode, languageCode: languageCode)]
    }

    var romCode: Int {
        switch self {
        case .whiteJapanese,  .whiteEnglish,  .whiteFrench,  .whiteItalian,  .whiteGerman,  .whiteSpanish,  .whiteKorean:  return 20
        case .blackJapanese,  .blackEnglish,  .blackFrench,  .blackItalian,  .blackGerman,  .blackSpanish,  .blackKorean:  return 21
        case .white2Japanese, .white2English, .white2French, .white2Italian, .white2German, .white2Spanish, .white2Korean: return 22
        case .black2Japanese, .black2English, .black2French, .black2Italian, .black2German, .black2Spanish, .black2Korean: return 23
        }
    }

    var languageCode: Int {
        switch self {
        case .blackJapanese,  .whiteJapanese,  .black2Japanese,  .white2Japanese:  return 1
        case .blackEnglish,   .whiteEnglish,   .black2English,   .white2English:   return 2
        case .blackFrench,    .whiteFrench,    .black2French,    .white2French:    return 3
        case .blackItalian,   .whiteItalian,   .black2Italian,   .white2Italian:   return 4
        case .blackGerman,    .whiteGerman,    .black2German,    .white2German:    return 5
        case .blackSpanish,   .whiteSpanish,   .black2Spanish,   .white2Spanish:   return 7
        case .blackKorean,    .whiteKorean,    .black2Korean,    .white2Korean:    return 8
        }
    }

    var serial: String {
        switch self {
        case .blackJapanese:  return "IRBJ"; case .blackEnglish:  return "IRBO"
        case .blackFrench:    return "IRBF"; case .blackItalian:  return "IRBI"
        case .blackGerman:    return "IRBD"; case .blackSpanish:  return "IRBS"
        case .blackKorean:    return "IRBK"
        case .whiteJapanese:  return "IRAJ"; case .whiteEnglish:  return "IRAO"
        case .whiteFrench:    return "IRAF"; case .whiteItalian:  return "IRAI"
        case .whiteGerman:    return "IRAD"; case .whiteSpanish:  return "IRAS"
        case .whiteKorean:    return "IRAK"
        case .black2Japanese: return "IREJ"; case .black2English: return "IREO"
        case .black2French:   return "IREF"; case .black2Italian: return "IREI"
        case .black2German:   return "IRED"; case .black2Spanish: return "IRES"
        case .black2Korean:   return "IREK"
        case .white2Japanese: return "IRDJ"; case .white2English: return "IRDO"
        case .white2French:   return "IRDF"; case .white2Italian: return "IRDI"
        case .white2German:   return "IRDD"; case .white2Spanish: return "IRDS"
        case .white2Korean:   return "IRDK"
        }
    }

    var displayName: String {
        switch self {
        case .blackJapanese:  return "ブラック";         case .blackEnglish:  return "Black Version"
        case .blackFrench:    return "Version Noire";   case .blackItalian:  return "Versione Nera"
        case .blackGerman:    return "Schwarze Edition"; case .blackSpanish: return "Edicion Negra"
        case .blackKorean:    return "블랙"
        case .whiteJapanese:  return "ホワイト";         case .whiteEnglish:  return "White Version"
        case .whiteFrench:    return "Version Blanche"; case .whiteItalian:  return "Versione Bianca"
        case .whiteGerman:    return "Weisse Edition";  case .whiteSpanish:  return "Edicion Blanca"
        case .whiteKorean:    return "화이트"
        case .black2Japanese: return "ブラック2";        case .black2English: return "Black Version 2"
        case .black2French:   return "Version Noire 2"; case .black2Italian: return "Versione Nera 2"
        case .black2German:   return "Schwarze Edition 2"; case .black2Spanish: return "Edicion Negra 2"
        case .black2Korean:   return "블랙2"
        case .white2Japanese: return "ホワイト2";        case .white2English: return "White Version 2"
        case .white2French:   return "Version Blanche 2"; case .white2Italian: return "Versione Bianca 2"
        case .white2German:   return "Weisse Edition 2"; case .white2Spanish: return "Edicion Blanca 2"
        case .white2Korean:   return "화이트2"
        }
    }

    var bits: Int { GameVersion.bits(romCode: romCode, languageCode: languageCode) }
    var isVersion2: Bool { checkMask(GameVersion.b2w2Mask) }
    func checkMask(_ mask: Int) -> Bool { (bits & mask) == bits }

    private static func bits(romCode: Int, languageCode: Int) -> Int {
        (1 << (8 - (romCode - 23))) | ((1 << (languageCode - 1)) & 0b111111111111)
    }

    private static let bySerial: [String: GameVersion] =
        Dictionary(uniqueKeysWithValues: Self.allCases.map { ($0.serial, $0) })

    private static let byCodes: [Int: GameVersion] =
        Dictionary(uniqueKeysWithValues: Self.allCases.map {
            (GameVersion.bits(romCode: $0.romCode, languageCode: $0.languageCode), $0)
        })
}