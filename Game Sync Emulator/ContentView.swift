//
//  ContentView.swift
//  Game Sync Emulator
//
//  Created by Alex Stern on 6/19/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        DebugLogView(userManager: AppServices.shared.userManager)
            .task {
                await AppServices.shared.startIfNeeded()
            }
    }
}

#Preview {
    ContentView()
}
