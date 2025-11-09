//
//  myfirstappApp.swift
//  myfirstapp Watch App
//
//  Created by Andrew Smith on 11/5/25.
//

import SwiftUI

@main
struct myfirstapp_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var motionManager = MotionManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(motionManager)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            print("App entered background")
            motionManager.handleAppDidEnterBackground()

        case .active:
            print("App became active")
            motionManager.handleAppWillEnterForeground()

            // Attempt recovery in case something stopped working
            if motionManager.isCollecting {
                motionManager.attemptRecovery()
            }

        case .inactive:
            print("App became inactive")

        @unknown default:
            print("Unknown scene phase")
        }
    }
}
