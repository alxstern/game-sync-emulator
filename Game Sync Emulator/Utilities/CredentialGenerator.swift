import Foundation
import Security

enum CredentialGenerator {

    static let challengeChartable = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890")

    // Returns a random server challenge string for the GameSpy auth handshake.
    static func generateChallenge(length: Int) -> String {
        String((0..<length).map { _ in challengeChartable.randomElement()! })
    }

    // Returns a URL-safe base64-encoded random token for WFC session auth.
    static func generateAuthToken(length: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }
}