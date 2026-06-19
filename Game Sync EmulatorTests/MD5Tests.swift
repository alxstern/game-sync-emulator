import Testing
@testable import Game_Sync_Emulator

@Suite("MD5")
struct MD5Tests {

    @Test func producesCorrectHexDigests() {
        #expect(MD5.digest("Hello World!")                == "ed076287532e86365e841e92bfc50d8c")
        #expect(MD5.digest("Some random string.")         == "8cfd799409ac5461004bca394a92b0af")
        #expect(MD5.digest("What is the meaning of life?") == "c74efaf9dd2782003ba4b27f15ef1049")
    }
}