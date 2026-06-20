import Testing
@testable import Game_Sync_Emulator

@Suite("GameSpyCodec")
struct GameSpyCodecTests {

    @Test func encodesCorrectly() {
        let pairs: [(String, String)] = [
            ("key", "value"),
            ("emptyValue", ""),
            ("hello", "world"),
            ("numberTest", "123")
        ]
        #expect(GameSpyCodec.encode(pairs) == "\\key\\value\\emptyValue\\\\hello\\world\\numberTest\\123")
    }

    @Test func decodesCorrectly() throws {
        let result = try GameSpyCodec.parse("\\key\\value\\emptyValue\\\\hello\\world\\numberTest\\123")
        #expect(result["key"]        == "value")
        #expect(result["emptyValue"] == "")
        #expect(result["hello"]      == "world")
        #expect(result["numberTest"] == "123")
    }

    @Test func throwsOnEmptyKey() {
        #expect(throws: GameSpyCodec.ParseError.emptyKey) {
            try GameSpyCodec.parse("\\some\\value\\\\emptyKey")
        }
    }

    @Test func throwsWhenNotStartingWithBackslash() {
        #expect(throws: GameSpyCodec.ParseError.doesNotStartWithBackslash) {
            try GameSpyCodec.parse("key\\value")
        }
    }

    @Test func throwsOnUnclosedFieldName() {
        #expect(throws: GameSpyCodec.ParseError.unclosedFieldName) {
            try GameSpyCodec.parse("\\hello\\world\\key")
        }
    }
}