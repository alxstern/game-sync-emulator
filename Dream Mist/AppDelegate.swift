import AppKit

// Stops every server on quit so ports 53/80/443/29900 don't linger held by a background
// process. Only fires on a clean quit (Cmd+Q, Dock > Quit, or closing the last window now that
// applicationShouldTerminateAfterLastWindowClosed is true below) — Xcode's Stop button SIGKILLs
// the process directly, which no app code can intercept.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // Async cleanup (HttpServer.stop() awaits SwiftNIO's graceful shutdown) can't finish inside
    // a synchronous applicationWillTerminate, so this defers actual termination with
    // .terminateLater until stopAll() completes, then tells AppKit to proceed.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await AppServices.shared.stopAll()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
