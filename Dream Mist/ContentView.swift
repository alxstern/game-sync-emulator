//
//  ContentView.swift
//  Dream Mist
//
//  Created by Alex Stern on 6/19/26.
//

import SwiftUI

struct ContentView: View {
    private enum Tab { case console, dashboard }
    @State private var selectedTab = Tab.console

    var body: some View {
        // Selection is driven explicitly rather than left to TabView's own state — swapping
        // the Dashboard tab's content from the login form to NavigationSplitView on login
        // otherwise resets the selected tab back to the first one.
        TabView(selection: $selectedTab) {
            DebugLogView(userManager: AppServices.shared.userManager)
                .tabItem { Label("Console", systemImage: "terminal") }
                .tag(Tab.console)

            DashboardView(playerManager: AppServices.shared.playerManager, dlcList: AppServices.shared.dlcList)
                .tabItem { Label("Dashboard", systemImage: "gamecontroller") }
                .tag(Tab.dashboard)
        }
        .task {
            await AppServices.shared.startIfNeeded()
        }
    }
}

#Preview {
    ContentView()
}
