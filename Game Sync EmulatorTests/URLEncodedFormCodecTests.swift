import Testing
@testable import Game_Sync_Emulator

@Suite("URLEncodedFormCodec")
struct URLEncodedFormCodecTests {

    let pairs: [(String, String)] = [
        ("hello", "world"),
        ("test", "space test"),
        ("emptyValue", ""),
        ("someNumber", "1234567890")
    ]

    @Test func encodesWithBase64() {
        #expect(URLEncodedFormCodec.encode(pairs) ==
            "hello=d29ybGQ*&test=c3BhY2UgdGVzdA**&emptyValue=&someNumber=MTIzNDU2Nzg5MA**")
    }

    @Test func encodesWithoutBase64() {
        #expect(URLEncodedFormCodec.encode(pairs, base64Values: false) ==
            "hello=world&test=space+test&emptyValue=&someNumber=1234567890")
    }

    @Test func parsesWithBase64() throws {
        let result = try URLEncodedFormCodec.parse(
            "hello=d29ybGQ*&test=c3BhY2UgdGVzdA**&emptyValue=&someNumber=MTIzNDU2Nzg5MA**")
        #expect(result["hello"]      == "world")
        #expect(result["test"]       == "space test")
        #expect(result["emptyValue"] == "")
        #expect(result["someNumber"] == "1234567890")
    }

    @Test func parsesWithoutBase64() throws {
        let result = try URLEncodedFormCodec.parse(
            "hello=world&test=space+test&emptyValue=&someNumber=1234567890",
            base64Values: false)
        #expect(result["hello"]      == "world")
        #expect(result["test"]       == "space test")
        #expect(result["emptyValue"] == "")
        #expect(result["someNumber"] == "1234567890")
    }

    @Test func throwsOnEmptyKey() {
        #expect(throws: URLEncodedFormCodec.ParseError.emptyKey) {
            try URLEncodedFormCodec.parse("someKey=someValue&=emptyKey", base64Values: false)
        }
    }

    @Test func throwsOnUnclosedFieldName() {
        #expect(throws: URLEncodedFormCodec.ParseError.unclosedFieldName) {
            try URLEncodedFormCodec.parse("someKey=someValue&notClosed", base64Values: false)
        }
    }
}
