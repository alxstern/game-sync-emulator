import Testing
@testable import Game_Sync_Emulator

@Suite("BGR555")
struct BGR555Tests {

    @Test func convertsBGR555ToRGB888() {
        // Primary colors
        #expect(BGR555.toRGB888(0x0000) == 0x000000)
        #expect(BGR555.toRGB888(0xFFFF) == 0xFFFFFF)
        #expect(BGR555.toRGB888(0x001F) == 0xFF0000)
        #expect(BGR555.toRGB888(0x03E0) == 0x00FF00)
        #expect(BGR555.toRGB888(0x7C00) == 0x0000FF)
        // Random colors
        #expect(BGR555.toRGB888(0x4E8F) == 0x7BA59C)
        #expect(BGR555.toRGB888(0xFE32) == 0x948CFF)
        #expect(BGR555.toRGB888(0x1097) == 0xBD2121)
        #expect(BGR555.toRGB888(0xAC6B) == 0x5A185A)
    }

    @Test func convertsRGB888ToBGR555() {
        // Primary colors
        #expect(BGR555.fromRGB888(0x000000) == 0x0000)
        #expect(BGR555.fromRGB888(0xFFFFFF) == 0x7FFF)
        #expect(BGR555.fromRGB888(0xFF0000) == 0x001F)
        #expect(BGR555.fromRGB888(0x00FF00) == 0x03E0)
        #expect(BGR555.fromRGB888(0x0000FF) == 0x7C00)
        // Random colors
        #expect(BGR555.fromRGB888(0x39F20C) == 0x07C7)
        #expect(BGR555.fromRGB888(0x9E2BD3) == 0x68B3)
        #expect(BGR555.fromRGB888(0xF07CDE) == 0x6DFE)
        #expect(BGR555.fromRGB888(0x26AC44) == 0x22A4)
    }
}