import Foundation

// Drop-in replacement for print() — also routes to LogStore for the in-app debug view.
// Always routes the append through the main queue since SwiftUI observes on main thread.
func log(_ message: String) {
    print(message)
    DispatchQueue.main.async {
        LogStore.shared.append(message)
    }
}
