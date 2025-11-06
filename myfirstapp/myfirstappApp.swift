//
//  myfirstappApp.swift
//  myfirstapp
//
//  Created by Andrew Smith on 11/5/25.
//

import SwiftUI

@main
struct myfirstappApp: App {
    init() {
        // Initialize WatchConnectivity on app launch
        _ = WatchConnectivityManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

