//
//  MotionManager.swift
//  myfirstapp Watch App
//
//  Created by Andrew Smith on 11/5/25.
//

import Foundation
import CoreMotion

struct AccelerometerReading {
    let timestamp: TimeInterval
    let x: Double
    let y: Double
    let z: Double
}

class MotionManager: ObservableObject {
    static let shared = MotionManager()

    private let motionManager = CMMotionManager()

    @Published var accelerometerData: [AccelerometerReading] = []
    @Published var isCollecting = false {
        didSet {
            // Broadcast state change to iPhone
            WatchConnectivityManager.shared.broadcastState(isCollecting: isCollecting)
        }
    }

    private var startTime: Date?
    var updateInterval: TimeInterval = 0.1 // 10 Hz - adjustable

    var isAvailable: Bool {
        motionManager.isAccelerometerAvailable
    }

    func startAccelerometerUpdates() {
        guard motionManager.isAccelerometerAvailable else {
            print("Accelerometer not available")
            return
        }

        guard !motionManager.isAccelerometerActive else {
            print("Accelerometer already active")
            return
        }

        accelerometerData.removeAll()
        motionManager.accelerometerUpdateInterval = updateInterval

        // Record start time
        startTime = Date()
        print("⏱️ Started collection at: \(startTime!)")

        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self else { return }

            if let error = error {
                print("Accelerometer error: \(error.localizedDescription)")
                return
            }

            guard let data = data else { return }

            let reading = AccelerometerReading(
                timestamp: data.timestamp,
                x: data.acceleration.x,
                y: data.acceleration.y,
                z: data.acceleration.z
            )

            self.accelerometerData.append(reading)
        }

        isCollecting = true
    }

    func stopAccelerometerUpdates() {
        motionManager.stopAccelerometerUpdates()
        isCollecting = false
    }

    func getElapsedTime() -> TimeInterval? {
        guard let startTime = startTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }

    func saveDataToCSV() -> URL? {
        guard !accelerometerData.isEmpty else {
            print("No data to save")
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let fileName = "accel_data_\(timestamp).csv"

        // Get documents directory
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access documents directory")
            return nil
        }

        let fileURL = documentsURL.appendingPathComponent(fileName)

        // Build CSV content with metadata as comments
        var csvText = ""

        // Add metadata header
        csvText += "# Accelerometer Data Export\n"
        csvText += "# Generated: \(ISO8601DateFormatter().string(from: Date()))\n"

        if let startTime = startTime {
            let isoFormatter = ISO8601DateFormatter()
            csvText += "# Start Time: \(isoFormatter.string(from: startTime))\n"

            let elapsedTime = getElapsedTime() ?? 0
            let minutes = Int(elapsedTime / 60)
            let seconds = Int(elapsedTime.truncatingRemainder(dividingBy: 60))
            csvText += "# End Time: \(isoFormatter.string(from: Date()))\n"
            csvText += "# Elapsed Time: \(elapsedTime) seconds (\(minutes)m \(seconds)s)\n"
        }

        csvText += "# Sample Rate: \(Int(1.0 / updateInterval)) Hz\n"
        csvText += "# Data Points: \(accelerometerData.count)\n"
        csvText += "#\n"

        // Add CSV header and data
        csvText += "Timestamp,X,Y,Z\n"
        for reading in accelerometerData {
            csvText += "\(reading.timestamp),\(reading.x),\(reading.y),\(reading.z)\n"
        }

        do {
            try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Saved to: \(fileURL.path)")
            return fileURL
        } catch {
            print("Error saving CSV: \(error.localizedDescription)")
            return nil
        }
    }

    func clearData() {
        accelerometerData.removeAll()
        startTime = nil
    }

    func saveAndTransferToiPhone(completion: @escaping (Bool, String) -> Void) {
        guard let fileURL = saveDataToCSV() else {
            completion(false, "Failed to save CSV file")
            return
        }

        let fileName = fileURL.lastPathComponent

        // Calculate elapsed time
        let elapsedTime = getElapsedTime() ?? 0
        print("⏱️ Elapsed time: \(elapsedTime) seconds (\(Int(elapsedTime / 60)) minutes)")

        // Create metadata
        let metadata: [String: Any] = [
            "elapsedTime": elapsedTime,
            "startTime": startTime?.timeIntervalSince1970 ?? 0,
            "endTime": Date().timeIntervalSince1970
        ]

        // Notify iPhone that transfer is starting
        WatchConnectivityManager.shared.notifyTransferStarting(fileName: fileName)

        // Transfer file to iPhone with metadata
        WatchConnectivityManager.shared.transferFile(url: fileURL, metadata: metadata) { success, message in
            completion(success, message)
        }
    }
}
