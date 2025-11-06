//
//  WatchConnectivityManager.swift
//  myfirstapp
//
//  Created by Andrew Smith on 11/5/25.
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

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
                print("Deleted file: \(url.lastPathComponent)")
            }
        } catch {
            print("Error deleting file: \(error.localizedDescription)")
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("Session deactivated")
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("Received file: \(file.fileURL.lastPathComponent)")

        // Move file to documents directory
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access documents directory")
            return
        }

        let destinationURL = documentsURL.appendingPathComponent(file.fileURL.lastPathComponent)

        do {
            // Remove existing file if it exists
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            // Copy the file
            try fileManager.copyItem(at: file.fileURL, to: destinationURL)

            DispatchQueue.main.async {
                self.receivedFiles.append(destinationURL)
                self.lastReceivedFileName = file.fileURL.lastPathComponent
                print("File saved to: \(destinationURL.path)")
            }
        } catch {
            print("Error saving received file: \(error.localizedDescription)")
        }
    }
}
