// GameSpy wire format: \key1\value1\key2\value2...
// Each field name and value is delimited by backslashes.
// Messages are terminated by \final\ which is handled by the network layer, not here.

enum GameSpyCodec {

    enum ParseError: Error, Equatable {
        case doesNotStartWithBackslash
        case emptyKey
        case unclosedFieldName
    }

    static func encode(_ pairs: [(String, String)]) -> String {
        pairs.map { "\\\($0.0)\\\($0.1)" }.joined()
    }

    static func parse(_ string: String) throws -> [String: String] {
        guard string.first == "\\" else {
            throw ParseError.doesNotStartWithBackslash
        }

        var result: [String: String] = [:]
        var remaining = string[string.index(after: string.startIndex)...]

        while !remaining.isEmpty {
            guard let keyEnd = remaining.firstIndex(of: "\\") else {
                throw ParseError.unclosedFieldName
            }

            let key = String(remaining[..<keyEnd])
            guard !key.isEmpty else { throw ParseError.emptyKey }
            remaining = remaining[remaining.index(after: keyEnd)...]

            if let valueEnd = remaining.firstIndex(of: "\\") {
                result[key] = String(remaining[..<valueEnd])
                remaining = remaining[remaining.index(after: valueEnd)...]
            } else {
                result[key] = String(remaining)
                break
            }
        }

        return result
    }
}