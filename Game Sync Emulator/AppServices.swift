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

        dnsServer = DnsServer(hostIP: NetworkUtility.localIPAddress(), port: 5300)
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

        PortForwardingManager.setup()
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

        // Forward new relay log lines into the debug view so per-query relay events are visible.
        Task.detached {
            let initial = (try? String(contentsOfFile: "/tmp/entralinked_relay.log"))
                .map { $0.components(separatedBy: "\n").filter { !$0.isEmpty }.count } ?? 0
            var knownLines = initial
            while true {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard let content = try? String(contentsOfFile: "/tmp/entralinked_relay.log") else { continue }
                let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
                guard lines.count > knownLines else { continue }
                for line in lines[knownLines...] { log("relay: \(line)") }
                knownLines = lines.count
            }
        }
    }
}
