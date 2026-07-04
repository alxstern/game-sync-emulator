import AppKit

// Kills the detached relay process on quit (Cmd+Q) so it doesn't linger and hold
// ports 53/80/443. Doesn't fire on Xcode's Stop button (SIGKILL can't be caught).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        PortForwardingManager.teardown()
    }
}
