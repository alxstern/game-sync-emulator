import Testing
@testable import Game_Sync_Emulator

@Suite("GameVersion")
struct GameVersionTests {

    // MARK: Serial lookup

    @Test func looksUpBySerial() {
        #expect(GameVersion.lookup(serial: "IRBO") == .blackEnglish)
        #expect(GameVersion.lookup(serial: "IRAO") == .whiteEnglish)
        #expect(GameVersion.lookup(serial: "IREO") == .black2English)
        #expect(GameVersion.lookup(serial: "IRDO") == .white2English)
        #expect(GameVersion.lookup(serial: "IRBJ") == .blackJapanese)
        #expect(GameVersion.lookup(serial: "IRAK") == .whiteKorean)
        #expect(GameVersion.lookup(serial: "IRES") == .black2Spanish)
        #expect(GameVersion.lookup(serial: "IRDF") == .white2French)
    }

    @Test func returnsNilForUnknownSerial() {
        #expect(GameVersion.lookup(serial: "AAAA") == nil)
        #expect(GameVersion.lookup(serial: "")     == nil)
    }

    // MARK: ROM code + language code lookup

    @Test func looksUpByRomAndLanguageCodes() {
        #expect(GameVersion.lookup(romCode: 21, languageCode: 2) == .blackEnglish)
        #expect(GameVersion.lookup(romCode: 20, languageCode: 2) == .whiteEnglish)
        #expect(GameVersion.lookup(romCode: 23, languageCode: 2) == .black2English)
        #expect(GameVersion.lookup(romCode: 22, languageCode: 2) == .white2English)
        #expect(GameVersion.lookup(romCode: 21, languageCode: 1) == .blackJapanese)
        #expect(GameVersion.lookup(romCode: 22, languageCode: 8) == .white2Korean)
    }

    // MARK: isVersion2

    @Test func identifiesVersion2Games() {
        #expect(GameVersion.blackEnglish.isVersion2  == false)
        #expect(GameVersion.whiteJapanese.isVersion2 == false)
        #expect(GameVersion.black2English.isVersion2 == true)
        #expect(GameVersion.white2Korean.isVersion2  == true)
    }

    // MARK: Bitmask checks

    @Test func bwMaskCoversOnlyBWGames() {
        #expect(GameVersion.blackEnglish.checkMask(GameVersion.bwMask)   == true)
        #expect(GameVersion.whiteGerman.checkMask(GameVersion.bwMask)    == true)
        #expect(GameVersion.black2English.checkMask(GameVersion.bwMask)  == false)
        #expect(GameVersion.white2Spanish.checkMask(GameVersion.bwMask)  == false)
    }

    @Test func b2w2MaskCoversOnlyB2W2Games() {
        #expect(GameVersion.black2French.checkMask(GameVersion.b2w2Mask)  == true)
        #expect(GameVersion.white2Italian.checkMask(GameVersion.b2w2Mask) == true)
        #expect(GameVersion.blackEnglish.checkMask(GameVersion.b2w2Mask)  == false)
        #expect(GameVersion.whiteKorean.checkMask(GameVersion.b2w2Mask)   == false)
    }

    @Test func allMaskCoversEveryGame() {
        for version in GameVersion.allCases {
            #expect(version.checkMask(GameVersion.allMask) == true)
        }
    }

    @Test func languageMasksMatchCorrectVersions() {
        #expect(GameVersion.blackEnglish.checkMask(GameVersion.engMask)  == true)
        #expect(GameVersion.blackEnglish.checkMask(GameVersion.japMask)  == false)
        #expect(GameVersion.white2Korean.checkMask(GameVersion.korMask)  == true)
        #expect(GameVersion.white2Korean.checkMask(GameVersion.engMask)  == false)
    }

    // MARK: Serial roundtrip

    @Test func serialRoundtrips() {
        for version in GameVersion.allCases {
            #expect(GameVersion.lookup(serial: version.serial) == version)
        }
    }
}