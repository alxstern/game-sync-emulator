import Foundation

enum NasReturnCode: Int {
    case success             = 1
    case registrationSuccess = 2
    case internalServerError = 100
    case badRequest          = 102
    case userAlreadyExists   = 104
    case userExpired         = 108
    case userNotFound        = 204

    nonisolated var formatted: String { String(format: "%03d", rawValue) }
}
