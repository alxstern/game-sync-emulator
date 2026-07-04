//
//  Game_Sync_EmulatorApp.swift
//  Game Sync Emulator
//
//  Created by Alex Stern on 6/19/26.
//

import SwiftUI

@main
struct Game_Sync_EmulatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
