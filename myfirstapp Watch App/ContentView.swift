//
//  ContentView.swift
//  myfirstapp Watch App
//
//  Created by Andrew Smith on 11/5/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var motionManager = MotionManager.shared
    @StateObject private var connectivity = WatchConnectivityManager.shared
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()

                // Status indicator
                VStack(spacing: 6) {
                    Image(systemName: motionManager.isCollecting ? "waveform.path" : "checkmark.circle")
                        .font(.title3)
                        .foregroundColor(motionManager.isCollecting ? .green : .gray)

                    Text(motionManager.isCollecting ? "Collecting..." : "Ready")
                        .font(.subheadline)
                        .foregroundColor(motionManager.isCollecting ? .green : .secondary)
                }

                Spacer()
                Spacer()

                // Start/Stop button
                Button(action: {
                    if motionManager.isCollecting {
                        // Stop and auto-transfer in background
                        stopAndTransfer()
                    } else {
                        motionManager.startAccelerometerUpdates()
                    }
                }) {
                    Text(motionManager.isCollecting ? "Stop & Send" : "Start")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(motionManager.isCollecting ? .red : .green)

                Spacer()
            }
            .padding()

            // Toast notification overlay
            if showToast {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(toastMessage)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(10)
                    .padding(.bottom, 8)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            if !motionManager.isAvailable {
                errorMessage = "Accelerometer not available on this device"
            }
        }
    }

    private func stopAndTransfer() {
        // Stop collecting immediately
        motionManager.stopAccelerometerUpdates()

        // Check if we have data
        guard !motionManager.accelerometerData.isEmpty else {
            return
        }

        let dataCount = motionManager.accelerometerData.count

        // Transfer in background - user can start new recording immediately
        motionManager.saveAndTransferToiPhone { success, message in
            DispatchQueue.main.async {
                if success {
                    // Show toast notification when transfer completes
                    toastMessage = "Sent \(dataCount) points"
                    withAnimation {
                        showToast = true
                    }

                    // Auto-dismiss after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showToast = false
                        }
                    }

                    motionManager.clearData()
                } else {
                    errorMessage = message
                }
            }
        }
    }
}
