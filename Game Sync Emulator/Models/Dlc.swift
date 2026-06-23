import Foundation

struct Dlc {
    let path: URL
    let name: String
    let gameCode: String
    let type: String
    let index: Int
    let projectedSize: Int
    let checksum: Int
    // False when the file lacked an embedded checksum — the server appends one before sending.
    let checksumEmbedded: Bool
}