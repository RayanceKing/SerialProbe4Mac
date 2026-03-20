//
//  SerialProbeApp.swift
//  SerialProbe
//
//  Created by rayanceking on 2026/3/20.
//

import SwiftUI

@main
struct SerialProbeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1380, height: 880)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified(showsTitle: false))
    }
}
