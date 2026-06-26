//
//  ContentView.swift
//  Game Sync Emulator
//
//  Created by Alex Stern on 6/19/26.
//

import SwiftUI

struct ContentView: View {
    private let dnsServer = DnsServer(hostIP: "127.0.0.1", port: 5300)
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

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .task {
            do {
                try await dnsServer.start()
            } catch {
                print("Failed to start DNS server: \(error)")
            }
            do {
                try await httpServer.start(
                    userManager: userManager,
                    playerManager: playerManager,
                    dlcList: dlcList,
                    configuration: configuration
                )
            } catch {
                print("Failed to start HTTP server: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
