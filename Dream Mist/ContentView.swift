//
//  ContentView.swift
//  Dream Mist
//
//  Created by Alex Stern on 6/19/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        DashboardView(playerManager: AppServices.shared.playerManager, dlcList: AppServices.shared.dlcList)
            .task {
                await AppServices.shared.startIfNeeded()
            }
    }
}

#Preview {
    ContentView()
}
