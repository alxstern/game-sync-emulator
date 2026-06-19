// Converts between RGB888 (standard 24-bit) and BGR555 (DS native 15-bit) color formats.
// BGR555 packs three 5-bit channels into 15 bits: [14:10]=blue, [9:5]=green, [4:0]=red.

enum BGR555 {

    static func toRGB888(_ color: Int) -> Int {
        let red   = (color & 0x1F) << 3
        let green = ((color >> 5)  & 0x1F) << 3
        let blue  = ((color >> 10) & 0x1F) << 3
        return ((red   | red   >> 5) << 16)
             | ((green | green >> 5) << 8)
             |  (blue  | blue  >> 5)
    }

    static func fromRGB888(_ color: Int) -> Int {
        let red   = (color >> 16) & 0xFF
        let green = (color >> 8)  & 0xFF
        let blue  =  color        & 0xFF
        return (red >> 3) | ((green >> 3) << 5) | ((blue >> 3) << 10)
    }
}