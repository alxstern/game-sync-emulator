import Foundation

struct ServiceSession {
    let user: User
    let service: String
    let branchCode: String
    let challengeHash: String
    let expiry: Date

    nonisolated init(user: User, service: String, branchCode: String, challengeHash: String, duration: TimeInterval) {
        self.user = user
        self.service = service
        self.branchCode = branchCode
        self.challengeHash = challengeHash
        self.expiry = Date.now.addingTimeInterval(duration)
    }

    nonisolated var isExpired: Bool { Date.now > expiry }
}