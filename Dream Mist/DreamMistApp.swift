//
//  DreamMistApp.swift
//  Dream Mist
//
//  Created by Alex Stern on 6/19/26.
//

import SwiftUI

@main
struct DreamMistApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
