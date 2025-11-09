//
//  ContentView.swift
//  myfirstapp Watch App
//
//  Created by Andrew Smith on 11/5/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var motionManager: MotionManager
    @StateObject private var connectivity = WatchConnectivityManager.shared
    @State private var showSaveAlert = false
    @State private var saveMessage = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Always On Display tip banner
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                    Text("Enable Always On Display for continuous real-time data")
                        .font(.caption2)
                        .multilineTextAlignment(.leading)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(8)

                // Status indicator with session state
                VStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.title)
                        .foregroundColor(statusColor)

                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Background indicator
                    if case .backgrounded = motionManager.sessionState {
                        HStack(spacing: 4) {
                            Image(systemName: "moon.fill")
                                .font(.caption2)
                            Text("Background Active")
                                .font(.caption2)
                        }
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(8)
                    }

                    // Session duration
                    if motionManager.isCollecting {
                        Text(formatDuration(motionManager.sessionDuration))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
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

                // Reset part counter button (persistent - always visible when not collecting)
                if !motionManager.isCollecting {
                    Button(action: {
                        motionManager.resetPartCounter()
                    }) {
                        Label("Reset Part #", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
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

    // MARK: - Status Helpers

    private var statusIcon: String {
        switch motionManager.sessionState {
        case .idle:
            return "waveform.path.badge.minus"
        case .starting:
            return "waveform.path.badge.plus"
        case .running:
            return "waveform.path"
        case .backgrounded:
            return "waveform.path"
        case .stopping:
            return "stop.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    private var statusColor: Color {
        switch motionManager.sessionState {
        case .idle:
            return .gray
        case .starting:
            return .orange
        case .running:
            return .green
        case .backgrounded:
            return .green
        case .stopping:
            return .orange
        case .error:
            return .red
        }
    }

    private var statusText: String {
        switch motionManager.sessionState {
        case .idle:
            return "Ready"
        case .starting:
            return "Starting..."
        case .running:
            return "Collecting"
        case .backgrounded:
            return "Background"
        case .stopping:
            return "Stopping..."
        case .error(let message):
            return "Error: \(message)"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
