import Foundation
import Combine

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
}

final class LogStore: ObservableObject, @unchecked Sendable {
    static let shared = LogStore()
    @Published private(set) var entries: [LogEntry] = []

    private init() {}

    func append(_ message: String) {
        entries.append(LogEntry(timestamp: Date(), message: message))
        if entries.count > 500 {
            entries.removeFirst(entries.count - 500)
        }
    }
}
