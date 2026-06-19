import Testing
@testable import Game_Sync_Emulator

@Suite("CRC16")
struct CRC16Tests {

    @Test func fullArrayChecksums() {
        #expect(CRC16.calc([114, 49, 226, 206, 46, 194, 47, 39, 171, 73, 165, 40, 21, 176, 161, 253]) == 0xEF9D)
        #expect(CRC16.calc([224, 161, 74, 56, 2, 199, 90, 78, 81, 81, 130, 29, 8, 1, 65, 249]) == 0x23DF)
        #expect(CRC16.calc([128, 47, 212, 118, 1, 91, 124, 104, 2, 252, 172, 180]) == 0x263D)
        #expect(CRC16.calc([247, 108, 151, 223, 146, 248, 33, 44]) == 0xBF19)
    }

    @Test func slicedArrayChecksums() {
        let bytes: [UInt8] = [81, 175, 187, 238, 70, 162, 195, 73, 193, 56, 56, 113, 181, 169, 226, 225, 180, 76, 136, 242, 177, 213, 139, 234, 23, 9, 175, 77, 64, 163, 48, 1]
        #expect(CRC16.calc(bytes, offset: 0,  length: 4)  == 0xC8F5)
        #expect(CRC16.calc(bytes, offset: 4,  length: 8)  == 0x6093)
        #expect(CRC16.calc(bytes, offset: 8,  length: 8)  == 0xD7C3)
        #expect(CRC16.calc(bytes, offset: 16, length: 16) == 0xFF5C)
    }

    @Test func integerChecksums() {
        #expect(CRC16.calc(Int32(12345))        == 0x9EFB)
        #expect(CRC16.calc(Int32(847190349))    == 0x005E)
        #expect(CRC16.calc(Int32.max)           == 0x8C87)
        #expect(CRC16.calc(Int32.min)           == 0x1548)
    }
}
