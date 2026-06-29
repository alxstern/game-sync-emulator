//
//  ContentView.swift
//  Game Sync Emulator
//
//  Created by Alex Stern on 6/19/26.
//

import SwiftUI

struct ContentView: View {
    private let dnsServer = DnsServer(hostIP: NetworkUtility.localIPAddress(), port: 5300)
    private let httpServer = HttpServer()

    private static let appSupportURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Entralinked", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    private let userManager   = UserManager(dataDirectory: appSupportURL.appendingPathComponent("users"))
    private let playerManager = PlayerManager(dataDirectory: appSupportURL.appendingPathComponent("players"))
    private let dlcList       = DlcList(dataDirectory: appSupportURL.appendingPathComponent("dlc"))
    private let configuration = Configuration.default
    private let gameSpyServer = GameSpyServer()

    var body: some View {
        DebugLogView(userManager: userManager)
            .task {
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
}

#Preview {
    ContentView()
}
