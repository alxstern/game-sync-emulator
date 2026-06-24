//
//  ContentView.swift
//  Game Sync Emulator
//
//  Created by Alex Stern on 6/19/26.
//

import SwiftUI

struct ContentView: View {
    private let dnsServer = DnsServer(hostIP: "127.0.0.1", port: 5300)

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
        }
    }
}

#Preview {
    ContentView()
}
