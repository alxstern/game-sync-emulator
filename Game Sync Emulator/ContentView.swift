//
//  ContentView.swift
//  Game Sync Emulator
//
//  Created by Alex Stern on 6/19/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DebugLogView(userManager: AppServices.shared.userManager)
                .tabItem { Label("Console", systemImage: "terminal") }

            DashboardView(playerManager: AppServices.shared.playerManager)
                .tabItem { Label("Dashboard", systemImage: "gamecontroller") }
        }
        .task {
            await AppServices.shared.startIfNeeded()
        }
    }
}

#Preview {
    ContentView()
}
