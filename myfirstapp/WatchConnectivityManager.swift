//
//  WatchConnectivityManager.swift
//  myfirstapp
//
//  Created by Andrew Smith on 11/5/25.
//

import Foundation
import WatchConnectivity

struct FileItem: Identifiable, Equatable {
    let id: String // filename
    enum Status: Equatable {
        case transferring
        case available
    }
    let status: Status
    let url: URL?
    let filename: String

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        // Compare all fields to ensure SwiftUI detects changes
        lhs.id == rhs.id &&
        lhs.status == rhs.status &&
        lhs.url == rhs.url &&
        lhs.filename == rhs.filename
    }
}

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var files: [FileItem] = []
    @Published var isWatchCollecting: Bool = false
    @Published var isWatchReachable: Bool = false

    // Legacy - kept for compatibility but will migrate to files array
    @Published var receivedFiles: [URL] = []
    @Published var lastReceivedFileName: String?

    private override init() {
        super.init()

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }

        // Load existing files from documents directory
        loadExistingFiles()
    }

    // Load all existing CSV files from documents directory
    func loadExistingFiles() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access documents directory")
            return
        }

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)

            // Filter for CSV files and sort by creation date (newest first)
            let csvFiles = fileURLs
                .filter { $0.pathExtension == "csv" }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 > date2
                }

            DispatchQueue.main.async {
                self.receivedFiles = csvFiles

                // Convert to new FileItem structure
                self.files = csvFiles.map { url in
                    FileItem(
                        id: url.lastPathComponent,
                        status: .available,
                        url: url,
                        filename: url.lastPathComponent
                    )
                }

                print("Loaded \(csvFiles.count) existing files")
            }
        } catch {
            print("Error loading existing files: \(error.localizedDescription)")
        }
    }

    // Delete a file from filesystem and update the array
    func deleteFile(at url: URL) {
        let fileManager = FileManager.default

        do {
            try fileManager.removeItem(at: url)
            DispatchQueue.main.async {
                self.receivedFiles.removeAll { $0 == url }
                self.files.removeAll { $0.url == url }
                print("Deleted file: \(url.lastPathComponent)")
            }
        } catch {
            print("Error deleting file: \(error.localizedDescription)")
        }
    }

    func deleteFile(named filename: String) {
        DispatchQueue.main.async {
            if let fileItem = self.files.first(where: { $0.filename == filename }),
               let url = fileItem.url {
                self.deleteFile(at: url)
            }
        }
    }

    // MARK: - Remote Control Commands

    func sendStartCommand(completion: @escaping (Result<String, Error>) -> Void) {
        guard WCSession.default.activationState == .activated else {
            completion(.failure(NSError(domain: "WatchConnectivity", code: 1, userInfo: [NSLocalizedDescriptionKey: "WatchConnectivity not activated"])))
            return
        }

        guard WCSession.default.isReachable else {
            completion(.failure(NSError(domain: "WatchConnectivity", code: 2, userInfo: [NSLocalizedDescriptionKey: "Watch not reachable - make sure Watch app is open"])))
            return
        }

        let message = ["command": "start"]

        WCSession.default.sendMessage(message, replyHandler: { reply in
            DispatchQueue.main.async {
                if let status = reply["status"] as? String {
                    self.isWatchCollecting = (status == "collecting")
                    let message = reply["message"] as? String ?? "Started"
                    completion(.success(message))
                } else if let error = reply["error"] as? String {
                    completion(.failure(NSError(domain: "WatchConnectivity", code: 3, userInfo: [NSLocalizedDescriptionKey: error])))
                }
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        })
    }

    func sendStopCommand(completion: @escaping (Result<String, Error>) -> Void) {
        guard WCSession.default.activationState == .activated else {
            completion(.failure(NSError(domain: "WatchConnectivity", code: 1, userInfo: [NSLocalizedDescriptionKey: "WatchConnectivity not activated"])))
            return
        }

        guard WCSession.default.isReachable else {
            completion(.failure(NSError(domain: "WatchConnectivity", code: 2, userInfo: [NSLocalizedDescriptionKey: "Watch not reachable - make sure Watch app is open"])))
            return
        }

        let message = ["command": "stop"]

        WCSession.default.sendMessage(message, replyHandler: { reply in
            DispatchQueue.main.async {
                if let status = reply["status"] as? String {
                    self.isWatchCollecting = (status == "collecting")
                    let message = reply["message"] as? String ?? "Stopped"
                    completion(.success(message))
                } else if let error = reply["error"] as? String {
                    completion(.failure(NSError(domain: "WatchConnectivity", code: 3, userInfo: [NSLocalizedDescriptionKey: error])))
                }
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        })
    }

    func requestStatus() {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else {
            return
        }

        let message = ["command": "requestStatus"]

        WCSession.default.sendMessage(message, replyHandler: { reply in
            DispatchQueue.main.async {
                if let status = reply["status"] as? String {
                    self.isWatchCollecting = (status == "collecting")
                }
            }
        }, errorHandler: { error in
            print("Error requesting status: \(error.localizedDescription)")
        })
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("WCSession activation failed: \(error.localizedDescription)")
            } else {
                print("WCSession activated with state: \(activationState.rawValue)")
                self.isWatchReachable = session.isReachable
                // Request initial status when session activates
                self.requestStatus()
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("Session deactivated")
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            print("Watch reachability changed: \(session.isReachable)")

            // Request status when Watch becomes reachable
            if session.isReachable {
                self.requestStatus()
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        print("📦 Received application context: \(applicationContext)")

        DispatchQueue.main.async {
            // Handle collection state updates
            if let isCollecting = applicationContext["isCollecting"] as? Bool {
                self.isWatchCollecting = isCollecting
                print("📊 Updated collection state: isCollecting=\(isCollecting)")
            }

            // Handle incoming file transfer notifications
            if let fileName = applicationContext["transferringFile"] as? String {
                print("⏳ File transfer notification received: \(fileName)")

                // Check if file already exists in our list
                if let existingIndex = self.files.firstIndex(where: { $0.filename == fileName }) {
                    let existing = self.files[existingIndex]

                    // Only update if not already available (file might have arrived first)
                    if existing.status != .available {
                        self.files[existingIndex] = FileItem(
                            id: fileName,
                            status: .transferring,
                            url: nil,
                            filename: fileName
                        )
                        print("🔄 Updated file status to transferring: \(fileName)")
                    } else {
                        print("⏭️  File already available, skipping transferring state: \(fileName)")
                    }
                } else {
                    // Add new pending file at the top
                    let pendingFile = FileItem(
                        id: fileName,
                        status: .transferring,
                        url: nil,
                        filename: fileName
                    )
                    self.files.insert(pendingFile, at: 0)
                    print("➕ Added new pending file to list: \(fileName)")
                }
            }
        }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let fileName = file.fileURL.lastPathComponent
        print("📥 FILE RECEIVED: \(fileName)")

        // Move file to documents directory
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return
        }

        let destinationURL = documentsURL.appendingPathComponent(fileName)

        do {
            // Remove existing file if it exists
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
                print("🗑️  Removed existing file")
            }

            // Copy the file
            try fileManager.copyItem(at: file.fileURL, to: destinationURL)
            print("💾 File saved to: \(destinationURL.path)")

            DispatchQueue.main.async {
                print("🔄 UPDATING UI for file: \(fileName)")

                // Update legacy array
                self.receivedFiles.append(destinationURL)
                self.lastReceivedFileName = fileName

                // Find existing entry or create new
                if let existingIndex = self.files.firstIndex(where: { $0.filename == fileName }) {
                    // File was in list (probably transferring), update to available
                    print("   Found existing entry at index \(existingIndex), updating to available")

                    self.files[existingIndex] = FileItem(
                        id: fileName,
                        status: .available,
                        url: destinationURL,
                        filename: fileName
                    )
                } else {
                    // File wasn't in list, add as available at top
                    print("   No existing entry, adding new available file")

                    let newFile = FileItem(
                        id: fileName,
                        status: .available,
                        url: destinationURL,
                        filename: fileName
                    )
                    self.files.insert(newFile, at: 0)
                }

                // Explicitly notify observers
                self.objectWillChange.send()

                print("✅ UI UPDATE COMPLETE - files array now has \(self.files.count) items")
                print("   File status: \(self.files.first(where: { $0.filename == fileName })?.status == .available ? "AVAILABLE" : "UNKNOWN")")
            }
        } catch {
            print("❌ Error saving received file: \(error.localizedDescription)")
        }
    }
}
