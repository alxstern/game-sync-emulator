import Foundation

// URL-encoded form codec (application/x-www-form-urlencoded).
// Used by the NAS, PGL, and DLS HTTP handlers for all DS request and response bodies.
//
// Nintendo's variant Base64-encodes values and replaces standard padding characters:
//   '=' → '*'    '+' → '.'    '/' → '-'

enum URLEncodedFormCodec {

    enum ParseError: Error, Equatable {
        case emptyKey
        case unclosedFieldName
    }

    static func encode(_ pairs: [(String, String)], base64Values: Bool = true) -> String {
        pairs.map { key, value in
            "\(formEncode(key))=\(base64Values ? nintendoBase64Encode(value) : formEncode(value))"
        }.joined(separator: "&")
    }

    static func parse(_ string: String, base64Values: Bool = true) throws -> [String: String] {
        var result: [String: String] = [:]

        for pair in string.split(separator: "&", omittingEmptySubsequences: false) {
            guard let eqRange = pair.range(of: "=") else {
                throw ParseError.unclosedFieldName
            }
            let key = formDecode(String(pair[..<eqRange.lowerBound]))
            guard !key.isEmpty else { throw ParseError.emptyKey }
            let rawValue = String(pair[eqRange.upperBound...])
            result[key] = base64Values ? nintendoBase64Decode(rawValue) : formDecode(rawValue)
        }

        return result
    }

    // Characters that don't need percent-encoding in form data (space handled separately).
    private static let formSafeCharacters: CharacterSet = {
        var chars = CharacterSet.alphanumerics
        chars.insert(charactersIn: "_.- ")
        return chars
    }()

    private static func formEncode(_ string: String) -> String {
        let encoded = string.addingPercentEncoding(withAllowedCharacters: formSafeCharacters) ?? string
        return encoded.replacingOccurrences(of: " ", with: "+")
    }

    private static func formDecode(_ string: String) -> String {
        string.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? string
    }

    private static func nintendoBase64Encode(_ string: String) -> String {
        (string.data(using: .isoLatin1) ?? Data())
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "*")
            .replacingOccurrences(of: "+", with: ".")
            .replacingOccurrences(of: "/", with: "-")
    }

    private static func nintendoBase64Decode(_ string: String) -> String {
        let standard = string
            .replacingOccurrences(of: "*", with: "=")
            .replacingOccurrences(of: ".", with: "+")
            .replacingOccurrences(of: "-", with: "/")
        guard let data = Data(base64Encoded: standard) else { return string }
        return String(data: data, encoding: .isoLatin1) ?? string
    }
}