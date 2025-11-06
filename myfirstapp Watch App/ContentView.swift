//
//  ContentView.swift
//  myfirstapp Watch App
//
//  Created by Andrew Smith on 11/5/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    @StateObject private var connectivity = WatchConnectivityManager.shared
    @State private var showSaveAlert = false
    @State private var saveMessage = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Status indicator
                VStack(spacing: 4) {
                    Image(systemName: motionManager.isCollecting ? "waveform.path" : "waveform.path.badge.minus")
                        .font(.title)
                        .foregroundColor(motionManager.isCollecting ? .green : .gray)

                    Text(motionManager.isCollecting ? "Collecting..." : "Ready")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)

                // Data counter
                VStack(spacing: 4) {
                    Text("\(motionManager.accelerometerData.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("data points")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Latest reading
                if let latest = motionManager.accelerometerData.last {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("X:")
                                .foregroundColor(.secondary)
                            Text(String(format: "%.3f", latest.x))
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("Y:")
                                .foregroundColor(.secondary)
                            Text(String(format: "%.3f", latest.y))
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("Z:")
                                .foregroundColor(.secondary)
                            Text(String(format: "%.3f", latest.z))
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.caption)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }

                // Start/Stop button
                Button(action: {
                    if motionManager.isCollecting {
                        motionManager.stopAccelerometerUpdates()
                    } else {
                        motionManager.startAccelerometerUpdates()
                    }
                }) {
                    Text(motionManager.isCollecting ? "Stop" : "Start")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(motionManager.isCollecting ? .red : .green)

                // Save and Transfer button
                Button(action: saveAndTransfer) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Label("Send to iPhone", systemImage: "iphone.and.arrow.forward")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .disabled(motionManager.accelerometerData.isEmpty || isSaving)

                // Clear button
                if !motionManager.accelerometerData.isEmpty && !motionManager.isCollecting {
                    Button(action: {
                        motionManager.clearData()
                    }) {
                        Label("Clear Data", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding()
        }
        .alert("Saved", isPresented: $showSaveAlert) {
            Button("OK") {}
        } message: {
            Text(saveMessage)
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

    private func saveAndTransfer() {
        isSaving = true
        let dataCount = motionManager.accelerometerData.count

        motionManager.saveAndTransferToiPhone { success, message in
            isSaving = false

            if success {
                saveMessage = "Sent \(dataCount) readings to iPhone!\n\(message)"
                showSaveAlert = true
                motionManager.clearData()
            } else {
                errorMessage = message
            }
        }
    }
}
