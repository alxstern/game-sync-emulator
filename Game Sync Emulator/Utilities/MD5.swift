import CryptoKit
import Foundation

// MD5 is cryptographically broken but required by the GameSpy authentication protocol.

enum MD5 {

    static func digest(_ string: String) -> String {
        let bytes = string.data(using: .isoLatin1) ?? Data()
        return digest(bytes).map { String(format: "%02x", $0) }.joined()
    }

    static func digest(_ data: Data) -> Data {
        Data(Insecure.MD5.hash(data: data))
    }
}