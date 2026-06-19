import Testing
@testable import Game_Sync_Emulator

@Suite("GSIDUtility")
struct GSIDUtilityTests {

    @Test func stringifiesCorrectly() {
        #expect(GSIDUtility.stringify(45991782)   == "G5T5MB69TA")
        #expect(GSIDUtility.stringify(381955984)  == "S6MJNM63AC")
        #expect(GSIDUtility.stringify(507849071)  == "RMLLERWPSA")
        #expect(GSIDUtility.stringify(576782280)  == "J89BGT23UD")
        #expect(GSIDUtility.stringify(1442582313) == "K3D29LTGSB")
        #expect(GSIDUtility.stringify(1640375006) == "8YJN6SKKGF")
    }

    @Test func rejectsInvalidIds() {
        // Illegal characters (0, 1, I, O are not in the alphabet)
        #expect(!GSIDUtility.isValid("0000000000"))
        #expect(!GSIDUtility.isValid("ABCDEFGHIJ"))
        #expect(!GSIDUtility.isValid("1OEKLRO493"))
        // Wrong length (must be exactly 10)
        #expect(!GSIDUtility.isValid("Y67UEN38K"))
        #expect(!GSIDUtility.isValid("3ER5K8MBN4C"))
        // Valid chars and length but bad checksum
        #expect(!GSIDUtility.isValid("VFWM2Q2ADH"))
        #expect(!GSIDUtility.isValid("44DAWDA4SH"))
        #expect(!GSIDUtility.isValid("J6F55U7FUE"))
        #expect(!GSIDUtility.isValid("8FAB4ZF6JF"))
        #expect(!GSIDUtility.isValid("HWLNS77HWD"))
        // Encodes a negative PID (sign bit set), which is not a valid game sync ID
        #expect(!GSIDUtility.isValid("VYSBC78999"))
        #expect(!GSIDUtility.isValid("2UD7GJ8999"))
        #expect(!GSIDUtility.isValid("BTULWN8999"))
        #expect(!GSIDUtility.isValid("ZW3JBQ9999"))
        #expect(!GSIDUtility.isValid("MNTNWB9999"))
    }

    @Test func acceptsValidIds() {
        #expect(GSIDUtility.isValid("VFWM2QAXNF"))
        #expect(GSIDUtility.isValid("44DAWDJKJ8"))
        #expect(GSIDUtility.isValid("J6F55UB2XD"))
        #expect(GSIDUtility.isValid("8FAB4Z3END"))
        #expect(GSIDUtility.isValid("HWLNS7BTNB"))
    }
}
