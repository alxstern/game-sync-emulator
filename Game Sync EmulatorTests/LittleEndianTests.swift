import Testing
@testable import Game_Sync_Emulator

@Suite("LittleEndian")
struct LittleEndianTests {

    @Test func roundTripsTypedValues() {
        let shortValue: Int16 = 0x6A84
        let intValue = Int32(bitPattern: 0xF827_EC80)
        let longValue: Int64 = 0x0094_8EC1_AB3F_2C88

        var writer = LittleEndianWriter()
        writer.writeShort(shortValue)
        writer.writeInt(intValue)
        writer.writeLong(longValue)

        var reader = LittleEndianReader(writer.data)
        #expect(reader.readShort() == shortValue)
        #expect(reader.readInt()   == intValue)
        #expect(reader.readLong()  == longValue)
    }
}