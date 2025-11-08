//
//  MotionManager.swift
//  myfirstapp Watch App
//
//  Created by Andrew Smith on 11/5/25.
//

import Foundation
import CoreMotion
import WatchKit
import os.log

// MARK: - CMSensorDataList Extension for Swift Iteration

extension CMSensorDataList: Sequence {
    public typealias Iterator = NSFastEnumerationIterator

    public func makeIterator() -> NSFastEnumerationIterator {
        return NSFastEnumerationIterator(self)
    }
}

// MARK: - Logging System

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!

    static let motionManager = OSLog(subsystem: subsystem, category: "MotionManager")
    static let session = OSLog(subsystem: subsystem, category: "ExtendedRuntimeSession")
    static let fileIO = OSLog(subsystem: subsystem, category: "FileIO")
    static let persistence = OSLog(subsystem: subsystem, category: "Persistence")
    static let transfer = OSLog(subsystem: subsystem, category: "Transfer")
    static let lifecycle = OSLog(subsystem: subsystem, category: "Lifecycle")
}

struct AccelerometerReading: Codable {
    let timestamp: TimeInterval
    let x: Double
    let y: Double
    let z: Double
    let source: String // "realtime" or "recorder"
}

enum SessionState {
    case idle
    case starting
    case running
    case backgrounded
    case stopping
    case error(String)
}

class MotionManager: NSObject, ObservableObject {
    static let shared = MotionManager()

    private var extendedRuntimeSession: WKExtendedRuntimeSession?
    private let recorder = CMSensorRecorder()
    private var recordingStartDate: Date?

    @Published var accelerometerData: [AccelerometerReading] = []
    @Published var isCollecting = false
    @Published var sessionState: SessionState = .idle
    @Published var sessionDuration: TimeInterval = 0

    private var sessionStartTime: Date?
    private var currentSessionFileName: String?
    private var durationTimer: Timer?
    private var sessionFileSequence = 0
    private var shouldContinueCollecting = false // Tracks user's intent to collect continuously
    private var allSessionFiles: [URL] = [] // Track all files for batch transfer

    var isAvailable: Bool {
        // CMSensorRecorder is available on Apple Watch Series 2 and later
        return CMSensorRecorder.isAccelerometerRecordingAvailable()
    }

    private override init() {
        super.init()
        print("[INIT] MotionManager initializing...")
        loadCollectionState()
        print("[INIT] MotionManager initialized")
    }

    func startAccelerometerUpdates() {
        print("\n[START] ═══════════════════════════════════════")
        print("[START] startAccelerometerUpdates() called")
        print("[START] Current state: \(sessionState)")

        guard CMSensorRecorder.isAccelerometerRecordingAvailable() else {
            print("[ERROR] CMSensorRecorder not available on this device")
            sessionState = .error("Sensor recorder not available")
            return
        }
        print("[CHECK] ✓ CMSensorRecorder available")

        guard !isCollecting else {
            print("[WARNING] Already collecting, ignoring start request")
            return
        }
        print("[CHECK] ✓ Not currently collecting")

        print("[STATE] Changing state: \(sessionState) → starting")
        sessionState = .starting

        // Mark that user wants continuous collection
        print("[STICKY] Enabling sticky mode (shouldContinueCollecting = true)")
        shouldContinueCollecting = true
        saveCollectionState()

        // Start extended runtime session for background execution
        print("[SESSION] Starting extended runtime session...")
        startExtendedRuntimeSession()

        // Start CMSensorRecorder for continuous background recording
        print("[RECORDER] Starting CMSensorRecorder for 3-day recording...")
        recordingStartDate = Date()
        recorder.recordAccelerometer(forDuration: 60 * 60 * 24 * 3) // 3 days
        print("[RECORDER] ✓ CMSensorRecorder started at \(recordingStartDate!)")
        print("[RECORDER] Will record continuously at 50Hz (downsampled to 10Hz on stop)")
        print("[RECORDER] Data will appear when you press Stop")

        // Clear in-memory data
        let previousDataCount = accelerometerData.count
        accelerometerData.removeAll()
        print("[DATA] Cleared in-memory data (previous count: \(previousDataCount))")

        // Create new session file name with sequence number
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        sessionFileSequence += 1
        currentSessionFileName = "accel_session_\(formatter.string(from: Date()))_part\(sessionFileSequence).csv"
        print("[FILE] Session file will be created on stop: \(currentSessionFileName ?? "nil")")
        print("[FILE] Session sequence: \(sessionFileSequence)")

        // Start session timer
        if sessionStartTime == nil {
            sessionStartTime = Date()
            print("[TIMER] Started new session timer at \(Date())")
        } else {
            print("[TIMER] Continuing existing session timer (started: \(sessionStartTime!))")
        }
        startDurationTimer()

        isCollecting = true
        print("[STATE] Changing state: starting → running")
        sessionState = .running
        print("[START] ✓ Started continuous background recording (CMSensorRecorder only)")
        print("[START] ═══════════════════════════════════════\n")
    }

    func stopAccelerometerUpdates() {
        print("\n[STOP] ═══════════════════════════════════════")
        print("[STOP] stopAccelerometerUpdates() called")
        print("[STOP] Current state: \(sessionState)")
        print("[STATE] Changing state: \(sessionState) → stopping")
        sessionState = .stopping

        // Mark that user no longer wants continuous collection
        print("[STICKY] Disabling sticky mode (shouldContinueCollecting = false)")
        shouldContinueCollecting = false
        saveCollectionState()

        // Retrieve and save CMSensorRecorder data
        if let startDate = recordingStartDate {
            print("[RECORDER] Retrieving all recorded data from \(startDate) to \(Date())...")
            print("[RECORDER] This may take a moment for long sessions...")
            retrieveAndSaveRecorderData(from: startDate, to: Date())
        } else {
            print("[RECORDER] [WARNING] No recording start date, no data to retrieve")
        }

        // Stop extended runtime session
        print("[SESSION] Stopping extended runtime session...")
        stopExtendedRuntimeSession()

        // Stop duration timer
        print("[TIMER] Stopping duration timer...")
        stopDurationTimer()

        let finalDataCount = accelerometerData.count
        let finalDuration = sessionDuration

        isCollecting = false
        print("[STATE] Changing state: stopping → idle")
        sessionState = .idle
        sessionDuration = 0
        sessionStartTime = nil
        recordingStartDate = nil

        print("[STOP] ✓ Stopped data collection")
        print("[STOP] Final stats - Data points: \(finalDataCount), Duration: \(Int(finalDuration))s")
        print("[STOP] Session file: \(currentSessionFileName ?? "none")")
        print("[STOP] ═══════════════════════════════════════\n")
    }

    // MARK: - CMSensorRecorder Data Retrieval

    private func retrieveAndSaveRecorderData(from startDate: Date, to endDate: Date) {
        print("[RECORDER] ──────────────────────────────────")
        print("[RECORDER] Retrieving CMSensorRecorder data...")
        print("[RECORDER] Time range: \(startDate) to \(endDate)")
        print("[RECORDER] Duration: \(endDate.timeIntervalSince(startDate))s")

        guard let fileName = currentSessionFileName else {
            print("[RECORDER] [ERROR] No current session file name")
            return
        }

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[RECORDER] [ERROR] Could not access documents directory")
            return
        }

        let fileURL = documentsURL.appendingPathComponent(fileName)

        // Retrieve recorder data
        guard let recorderData = recorder.accelerometerData(from: startDate, to: endDate) else {
            print("[RECORDER] [WARNING] No data available from CMSensorRecorder")
            return
        }

        // Create CSV file with header
        let header = "Timestamp,X,Y,Z,Source\n"
        do {
            try header.write(to: fileURL, atomically: true, encoding: .utf8)
            print("[RECORDER] ✓ Created CSV file with header")
        } catch {
            print("[RECORDER] [ERROR] Failed to create CSV: \(error.localizedDescription)")
            return
        }

        // Process and save recorder data in batches
        var sampleCount = 0
        var savedCount = 0
        var batchData: [AccelerometerReading] = []
        let downsampleFactor = 5 // 50Hz -> 10Hz (keep every 5th sample)

        print("[RECORDER] Processing and downsampling (50Hz -> 10Hz)...")

        autoreleasepool {
            for datum in recorderData {
                guard let datum = datum as? CMRecordedAccelerometerData else { continue }
                sampleCount += 1

                // Downsample: only keep every 5th sample
                if sampleCount % downsampleFactor != 0 {
                    continue
                }

                let timestamp = datum.startDate.timeIntervalSince1970
                let x = datum.acceleration.x
                let y = datum.acceleration.y
                let z = datum.acceleration.z

                // Validate data range (±8g is reasonable upper bound)
                if abs(x) > 8.0 || abs(y) > 8.0 || abs(z) > 8.0 {
                    print("[RECORDER] [WARNING] Outlier detected: x=\(x), y=\(y), z=\(z) - skipping")
                    continue
                }

                let reading = AccelerometerReading(
                    timestamp: timestamp,
                    x: x,
                    y: y,
                    z: z,
                    source: "recorder"
                )
                batchData.append(reading)
                accelerometerData.append(reading)  // Also add to in-memory array for UI

                // Write to file in batches of 1000 to manage memory
                if batchData.count >= 1000 {
                    if writeBatchToCSV(batch: batchData, fileURL: fileURL) {
                        savedCount += batchData.count
                    }
                    batchData.removeAll()
                }
            }
        }

        // Write any remaining batch
        if !batchData.isEmpty {
            if writeBatchToCSV(batch: batchData, fileURL: fileURL) {
                savedCount += batchData.count
            }
        }

        print("[RECORDER] ✓ Processing complete")
        print("[RECORDER] Total samples retrieved: \(sampleCount)")
        print("[RECORDER] After downsampling: \(savedCount) samples saved")
        print("[RECORDER] Sample rate: ~\(Double(savedCount) / endDate.timeIntervalSince(startDate)) Hz")
        print("[RECORDER] ──────────────────────────────────")
    }

    private func writeBatchToCSV(batch: [AccelerometerReading], fileURL: URL) -> Bool {
        guard !batch.isEmpty else { return false }

        // Build CSV content
        var csvText = ""
        for reading in batch {
            csvText += "\(reading.timestamp),\(reading.x),\(reading.y),\(reading.z),\(reading.source)\n"
        }

        // Append to file
        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            fileHandle.seekToEndOfFile()
            if let data = csvText.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
            return true
        } else {
            print("[RECORDER] [ERROR] Failed to open file for writing")
            return false
        }
    }

    // MARK: - Extended Runtime Session

    private func startExtendedRuntimeSession() {
        print("[SESSION] ──────────────────────────────────")
        print("[SESSION] Creating new WKExtendedRuntimeSession...")
        let session = WKExtendedRuntimeSession()
        self.extendedRuntimeSession = session
        session.delegate = self
        print("[SESSION] Delegate set to MotionManager")

        print("[SESSION] Calling session.start()...")
        session.start()
        print("[SESSION] ✓ Extended runtime session started")
        print("[SESSION] ──────────────────────────────────")
    }

    private func stopExtendedRuntimeSession() {
        print("[SESSION] ──────────────────────────────────")
        print("[SESSION] Invalidating extended runtime session...")
        extendedRuntimeSession?.invalidate()
        extendedRuntimeSession = nil
        print("[SESSION] ✓ Extended runtime session stopped and cleared")
        print("[SESSION] ──────────────────────────────────")
    }

    // MARK: - Data Persistence
    // Note: Session files are now created only when stopping collection (in retrieveAndSaveRecorderData)
    // No real-time buffering or intermediate file writes

    // MARK: - Duration Timer

    private func startDurationTimer() {
        print("[TIMER] Starting duration timer (1s interval)...")
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.sessionStartTime else { return }
            self.sessionDuration = Date().timeIntervalSince(startTime)
        }
        print("[TIMER] ✓ Duration timer started")
    }

    private func stopDurationTimer() {
        print("[TIMER] Stopping duration timer...")
        durationTimer?.invalidate()
        durationTimer = nil
        print("[TIMER] ✓ Duration timer stopped")
    }

    // MARK: - Background Recovery

    func handleAppDidEnterBackground() {
        print("\n[BACKGROUND] ═══════════════════════════════════════")
        print("[BACKGROUND] App entered background")
        print("[BACKGROUND] isCollecting: \(isCollecting)")

        if isCollecting {
            print("[STATE] Changing state: \(sessionState) → backgrounded")
            sessionState = .backgrounded
            print("[BACKGROUND] ✓ Extended runtime session maintaining data collection")
            print("[BACKGROUND] Data points collected: \(accelerometerData.count)")
        } else {
            print("[BACKGROUND] Not collecting, no state change needed")
        }
        print("[BACKGROUND] ═══════════════════════════════════════\n")
    }

    func handleAppWillEnterForeground() {
        print("\n[FOREGROUND] ═══════════════════════════════════════")
        print("[FOREGROUND] App entering foreground")
        print("[FOREGROUND] isCollecting: \(isCollecting)")

        if isCollecting {
            print("[STATE] Changing state: \(sessionState) → running")
            sessionState = .running
            print("[FOREGROUND] ✓ Resuming UI updates")
            print("[FOREGROUND] Data points collected: \(accelerometerData.count)")
        } else {
            print("[FOREGROUND] Not collecting, no state change needed")
        }
        print("[FOREGROUND] ═══════════════════════════════════════\n")
    }

    func attemptRecovery() {
        print("\n[RECOVERY] ═══════════════════════════════════════")
        print("[RECOVERY] attemptRecovery() called")
        print("[RECOVERY] shouldContinueCollecting: \(shouldContinueCollecting)")
        print("[RECOVERY] isCollecting: \(isCollecting)")

        // Only attempt recovery if user wants continuous collection
        guard shouldContinueCollecting else {
            print("[RECOVERY] ⊗ Recovery skipped - sticky mode disabled")
            print("[RECOVERY] ═══════════════════════════════════════\n")
            return
        }

        // CMSensorRecorder keeps recording in background automatically
        // Just need to restart extended runtime session if needed
        if extendedRuntimeSession == nil {
            print("[RECOVERY] ↻ Extended runtime session not active, restarting...")
            startExtendedRuntimeSession()

            isCollecting = true
            sessionState = .running
            print("[RECOVERY] ✓ Recovery successful - session restarted")
        } else {
            print("[RECOVERY] Extended runtime session still active, no recovery needed")
        }

        print("[RECOVERY] CMSensorRecorder continues recording in background")
        print("[RECOVERY] ═══════════════════════════════════════\n")
    }

    // MARK: - Legacy Methods (for compatibility)

    func saveDataToCSV() -> URL? {
        // If we have a current session file, return that
        if let fileName = currentSessionFileName {
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return nil
            }
            return documentsURL.appendingPathComponent(fileName)
        }

        // Otherwise create a new file with all data
        guard !accelerometerData.isEmpty else {
            print("No data to save")
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let fileName = "accel_data_\(timestamp).csv"

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access documents directory")
            return nil
        }

        let fileURL = documentsURL.appendingPathComponent(fileName)

        var csvText = "Timestamp,X,Y,Z,Source\n"
        for reading in accelerometerData {
            csvText += "\(reading.timestamp),\(reading.x),\(reading.y),\(reading.z),\(reading.source)\n"
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
        print("[CLEAR] ═══════════════════════════════════════")
        print("[CLEAR] Clearing all data and session files")

        // Clear in-memory data
        accelerometerData.removeAll()
        print("[CLEAR] Cleared in-memory data")

        // Delete all CSV files from documents directory
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[CLEAR] Could not access documents directory")
            return
        }

        do {
            let allFiles = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            let csvFiles = allFiles.filter { $0.pathExtension == "csv" }

            for fileURL in csvFiles {
                try FileManager.default.removeItem(at: fileURL)
                print("[CLEAR] Deleted: \(fileURL.lastPathComponent)")
            }

            print("[CLEAR] ✓ Deleted \(csvFiles.count) session file(s)")
        } catch {
            print("[CLEAR] Error deleting files: \(error.localizedDescription)")
        }

        // Clear tracking
        allSessionFiles.removeAll()
        currentSessionFileName = nil

        // Reset sequence counter
        sessionFileSequence = 0
        saveCollectionState()
        print("[CLEAR] Reset sequence counter to 0")

        print("[CLEAR] ═══════════════════════════════════════")
    }

    func resetPartCounter() {
        print("[RESET] ═══════════════════════════════════════")
        print("[RESET] Resetting part counter")
        print("[RESET] Previous counter: \(sessionFileSequence)")
        sessionFileSequence = 0
        saveCollectionState()
        print("[RESET] Counter reset to 0")
        print("[RESET] ═══════════════════════════════════════")
    }

    func saveAndTransferToiPhone(completion: @escaping (Bool, String) -> Void) {
        print("[TRANSFER] ═══════════════════════════════════════")
        print("[TRANSFER] Manual transfer initiated")

        // Collect all session files from documents directory
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(false, "Could not access documents directory")
            return
        }

        var sessionFiles: [URL] = []

        // Find all CSV files in documents directory
        do {
            let allFiles = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            sessionFiles = allFiles.filter { $0.pathExtension == "csv" }
            print("[TRANSFER] Found \(sessionFiles.count) session file(s):")
            for fileURL in sessionFiles {
                print("[TRANSFER]   - \(fileURL.lastPathComponent)")
            }
        } catch {
            print("[TRANSFER] Error scanning directory: \(error.localizedDescription)")
        }

        guard !sessionFiles.isEmpty else {
            completion(false, "No session files to transfer")
            return
        }

        // Transfer all files
        var successCount = 0
        var failCount = 0
        let group = DispatchGroup()

        for fileURL in sessionFiles {
            group.enter()
            print("[TRANSFER] Transferring: \(fileURL.lastPathComponent)")
            WatchConnectivityManager.shared.transferFile(url: fileURL) { success, message in
                if success {
                    successCount += 1
                } else {
                    failCount += 1
                    print("[TRANSFER] Failed to transfer \(fileURL.lastPathComponent): \(message)")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let message = "Transferred \(successCount) file(s)" + (failCount > 0 ? ", \(failCount) failed" : "")
            print("[TRANSFER] \(message)")
            print("[TRANSFER] ═══════════════════════════════════════")
            completion(failCount == 0, message)
        }
    }

    // MARK: - State Persistence

    private func saveCollectionState() {
        print("[PERSIST] ──────────────────────────────────")
        print("[PERSIST] Saving collection state to UserDefaults...")
        print("[PERSIST] shouldContinueCollecting: \(shouldContinueCollecting)")
        print("[PERSIST] sessionFileSequence: \(sessionFileSequence)")

        UserDefaults.standard.set(shouldContinueCollecting, forKey: "shouldContinueCollecting")
        UserDefaults.standard.set(sessionFileSequence, forKey: "sessionFileSequence")

        print("[PERSIST] ✓ State saved to disk")
        print("[PERSIST] ──────────────────────────────────")
    }

    private func loadCollectionState() {
        print("[PERSIST] ──────────────────────────────────")
        print("[PERSIST] Loading collection state from UserDefaults...")

        shouldContinueCollecting = UserDefaults.standard.bool(forKey: "shouldContinueCollecting")
        sessionFileSequence = UserDefaults.standard.integer(forKey: "sessionFileSequence")

        print("[PERSIST] shouldContinueCollecting: \(shouldContinueCollecting)")
        print("[PERSIST] sessionFileSequence: \(sessionFileSequence)")

        // If we were collecting when the app was terminated, restart automatically
        if shouldContinueCollecting {
            print("[PERSIST] ✓ Sticky mode was active - will auto-resume collection")
            print("[PERSIST] Scheduling auto-restart in 1.0 seconds...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                print("[PERSIST] ↻ Auto-restart timer fired, calling startAccelerometerUpdates()...")
                self?.startAccelerometerUpdates()
            }
        } else {
            print("[PERSIST] Sticky mode was not active - no auto-resume")
        }
        print("[PERSIST] ──────────────────────────────────")
    }

    // MARK: - Auto-Transfer

    private func transferSessionFileToiPhone(_ fileName: String) {
        print("[TRANSFER] ──────────────────────────────────")
        print("[TRANSFER] Initiating auto-transfer for: \(fileName)")

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("[TRANSFER] [ERROR] Could not access documents directory")
            print("[TRANSFER] ──────────────────────────────────")
            return
        }

        let fileURL = documentsURL.appendingPathComponent(fileName)
        print("[TRANSFER] Full path: \(fileURL.path)")

        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[TRANSFER] [ERROR] File does not exist at path")
            print("[TRANSFER] ──────────────────────────────────")
            return
        }

        // Get file size
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attrs[.size] as? Int64 ?? 0
            print("[TRANSFER] File size: \(fileSize) bytes (\(String(format: "%.2f", Double(fileSize)/1024.0)) KB)")
        } catch {
            print("[TRANSFER] [WARNING] Could not get file attributes: \(error.localizedDescription)")
        }

        // Track this file
        if !allSessionFiles.contains(fileURL) {
            allSessionFiles.append(fileURL)
            print("[TRANSFER] Added to tracking list (total files: \(allSessionFiles.count))")
        } else {
            print("[TRANSFER] File already in tracking list")
        }

        // Transfer in background
        print("[TRANSFER] Dispatching transfer to background queue...")
        DispatchQueue.global(qos: .utility).async {
            print("[TRANSFER] Background transfer started...")
            WatchConnectivityManager.shared.transferFile(url: fileURL) { success, message in
                if success {
                    print("[TRANSFER] ✓ Auto-transfer succeeded: \(fileName)")
                    print("[TRANSFER] Response: \(message)")
                } else {
                    print("[TRANSFER] ✗ Auto-transfer failed: \(fileName)")
                    print("[TRANSFER] Error: \(message)")
                }
            }
        }
        print("[TRANSFER] ──────────────────────────────────")
    }

    func transferAllSessionFiles(completion: @escaping (Bool, String) -> Void) {
        guard !allSessionFiles.isEmpty else {
            completion(false, "No session files to transfer")
            return
        }

        var successCount = 0
        var failCount = 0
        let group = DispatchGroup()

        for fileURL in allSessionFiles {
            group.enter()
            WatchConnectivityManager.shared.transferFile(url: fileURL) { success, message in
                if success {
                    successCount += 1
                } else {
                    failCount += 1
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let message = "Transferred \(successCount) file(s), \(failCount) failed"
            completion(failCount == 0, message)
        }
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension MotionManager: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("\n[DELEGATE] ═══════════════════════════════════════")
        print("[DELEGATE] extendedRuntimeSessionDidStart() called")
        print("[DELEGATE] ✓ Extended runtime session did start successfully")
        print("[DELEGATE] ═══════════════════════════════════════\n")
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("\n[DELEGATE] ═══════════════════════════════════════")
        print("[DELEGATE] extendedRuntimeSessionWillExpire() called")
        print("[DELEGATE] ⚠️ Extended runtime session will expire soon!")
        print("[DELEGATE] CMSensorRecorder continues recording in background")

        // If user wants continuous collection, restart extended runtime session
        if shouldContinueCollecting {
            print("[DELEGATE] Sticky mode active - will restart session")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                print("[DELEGATE] Main queue: Starting session restart...")

                // Stop current session
                print("[DELEGATE] Invalidating expired session...")
                self.extendedRuntimeSession?.invalidate()

                // Start a new extended runtime session
                print("[DELEGATE] Starting new extended runtime session...")
                self.startExtendedRuntimeSession()

                print("[DELEGATE] ✓ Session automatically restarted")
                print("[DELEGATE] CMSensorRecorder continues uninterrupted")
            }
        } else {
            print("[DELEGATE] Sticky mode disabled - no restart")
        }
        print("[DELEGATE] ═══════════════════════════════════════\n")
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        print("\n[DELEGATE] ═══════════════════════════════════════")
        print("[DELEGATE] extendedRuntimeSession:didInvalidateWith:error: called")
        print("[DELEGATE] ⚠️ Extended runtime session invalidated")
        print("[DELEGATE] Reason code: \(reason.rawValue)")

        if let error = error {
            print("[DELEGATE] [ERROR] \(error.localizedDescription)")
        } else {
            print("[DELEGATE] No error provided")
        }

        // CMSensorRecorder continues recording in background automatically
        print("[DELEGATE] CMSensorRecorder continues recording")

        // Note: Session file is kept on watch for manual transfer
        print("[DELEGATE] Session file saved: \(currentSessionFileName ?? "none")")

        // If user wants continuous collection, automatically restart
        if shouldContinueCollecting {
            print("[DELEGATE] Sticky mode active - scheduling recovery in 0.5s...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                print("[DELEGATE] Recovery timer fired, calling attemptRecovery()...")
                self?.attemptRecovery()
            }
        } else {
            print("[DELEGATE] Sticky mode disabled - no recovery")
        }
        print("[DELEGATE] ═══════════════════════════════════════\n")
    }
}
