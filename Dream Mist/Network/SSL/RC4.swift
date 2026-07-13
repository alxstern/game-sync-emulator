struct RC4 {
    private var s = [UInt8](0...255)
    private var i = 0
    private var j = 0

    init(key: [UInt8]) {
        guard !key.isEmpty else { return }
        var j = 0
        for i in 0...255 {
            j = (j + Int(s[i]) + Int(key[i % key.count])) & 0xFF
            s.swapAt(i, j)
        }
    }

    mutating func process(_ data: [UInt8]) -> [UInt8] {
        data.map { byte in
            i = (i + 1) & 0xFF
            j = (j + Int(s[i])) & 0xFF
            s.swapAt(i, j)
            return byte ^ s[(Int(s[i]) + Int(s[j])) & 0xFF]
        }
    }
}
