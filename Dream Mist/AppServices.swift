import Foundation

// Owns every server/manager for the process's lifetime. WindowGroup can spin up more than one
// ContentView (window restoration, File > New Window), and each would otherwise re-run .task
// and double-bind every port. Routing startup through this singleton makes that a no-op.
final class AppServices: @unchecked Sendable {
    static let shared = AppServices()

    let dnsServer: DnsServer
    let httpServer: HttpServer
    let gameSpyServer: GameSpyServer
    let userManager: UserManager
    let playerManager: PlayerManager
    let dlcList: DlcList
    let configuration: Configuration

    private let lock = NSLock()
    private var started = false

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Entralinked", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        dnsServer = DnsServer(hostIP: NetworkUtility.localIPAddress(), port: 53)
        httpServer = HttpServer()
        gameSpyServer = GameSpyServer()
        userManager = UserManager(dataDirectory: base.appendingPathComponent("users"))
        playerManager = PlayerManager(dataDirectory: base.appendingPathComponent("players"))

        let dlcDirectory = base.appendingPathComponent("dlc")
        DlcSeeder.seed(into: dlcDirectory)
        dlcList = DlcList(dataDirectory: dlcDirectory)
        configuration = Configuration.default
    }

    // Only starts servers on the first call; safe to call from every ContentView.task.
    func startIfNeeded() async {
        lock.lock()
        let alreadyStarted = started
        started = true
        lock.unlock()
        guard !alreadyStarted else { return }

        do {
            try await dnsServer.start()
        } catch {
            log("Failed to start DNS server: \(error)")
        }
        do {
            try await httpServer.start(
                userManager: userManager,
                playerManager: playerManager,
                dlcList: dlcList,
                configuration: configuration
            )
        } catch {
            log("Failed to start HTTP server: \(error)")
        }
        do {
            try await gameSpyServer.start(playerManager: playerManager, userManager: userManager)
        } catch {
            log("Failed to start GameSpy server: \(error)")
        }
    }

    // Stops every server so the ports are actually free the moment the app quits, instead of
    // only being freed whenever the OS gets around to reclaiming them from a dead process.
    // Called from AppDelegate before it lets the app finish terminating.
    func stopAll() async {
        dnsServer.stop()
        await httpServer.stop()
        gameSpyServer.stop()
    }
}
