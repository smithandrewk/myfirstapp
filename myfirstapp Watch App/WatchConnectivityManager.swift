//
//  WatchConnectivityManager.swift
//  myfirstapp Watch App
//
//  Created by Andrew Smith on 11/5/25.
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    @Published var lastTransferStatus: String?

    private override init() {
        super.init()

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func transferFile(url: URL, metadata: [String: Any]? = nil, completion: @escaping (Bool, String) -> Void) {
        guard WCSession.default.activationState == .activated else {
            completion(false, "Watch Connectivity not activated")
            return
        }

        // Merge provided metadata with default type
        var transferMetadata = metadata ?? [:]
        transferMetadata["type"] = "csv"

        // Transfer the file with metadata
        WCSession.default.transferFile(url, metadata: transferMetadata)

        print("📤 Transferring file with metadata: \(transferMetadata)")

        completion(true, "File queued for transfer to iPhone")
    }

    private var pendingTransferFileName: String?

    func broadcastState(isCollecting: Bool) {
        guard WCSession.default.activationState == .activated else {
            print("Cannot broadcast state - WCSession not activated")
            return
        }

        var context: [String: Any] = [
            "isCollecting": isCollecting,
            "timestamp": Date().timeIntervalSince1970
        ]

        // Include pending transfer if there is one
        if let fileName = pendingTransferFileName {
            context["transferringFile"] = fileName
        }

        do {
            try WCSession.default.updateApplicationContext(context)
            print("Broadcasted state to iPhone: isCollecting=\(isCollecting)")
        } catch {
            print("Failed to broadcast state: \(error.localizedDescription)")
        }
    }

    func notifyTransferStarting(fileName: String) {
        guard WCSession.default.activationState == .activated else {
            print("Cannot notify transfer - WCSession not activated")
            return
        }

        // Store the filename so future context updates include it
        pendingTransferFileName = fileName

        let context: [String: Any] = [
            "transferringFile": fileName,
            "isCollecting": MotionManager.shared.isCollecting,
            "timestamp": Date().timeIntervalSince1970
        ]

        do {
            try WCSession.default.updateApplicationContext(context)
            print("⏳ Notified iPhone that transfer is starting: \(fileName)")
        } catch {
            print("Failed to notify transfer: \(error.localizedDescription)")
        }
    }

    func clearPendingTransfer() {
        pendingTransferFileName = nil
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("WCSession activation failed: \(error.localizedDescription)")
            } else {
                print("WCSession activated with state: \(activationState.rawValue)")
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error = error {
            print("File transfer failed: \(error.localizedDescription)")
            clearPendingTransfer()
        } else {
            print("✅ File transfer completed successfully")

            // Clear the pending transfer state
            clearPendingTransfer()

            // Delete the file from Watch after successful transfer
            let fileURL = fileTransfer.file.fileURL
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("Deleted file from Watch: \(fileURL.lastPathComponent)")
            } catch {
                print("Error deleting file from Watch: \(error.localizedDescription)")
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        print("Received message from iPhone: \(message)")

        guard let command = message["command"] as? String else {
            replyHandler(["error": "Invalid command format"])
            return
        }

        let motionManager = MotionManager.shared

        DispatchQueue.main.async {
            switch command {
            case "start":
                if motionManager.isCollecting {
                    // Already collecting, treat as no-op
                    replyHandler(["status": "collecting", "message": "Already collecting"])
                } else {
                    motionManager.startAccelerometerUpdates()
                    replyHandler(["status": "collecting", "message": "Started collection"])
                }

            case "stop":
                if !motionManager.isCollecting {
                    // Not collecting, treat as no-op
                    replyHandler(["status": "idle", "message": "Not collecting"])
                } else {
                    motionManager.stopAccelerometerUpdates()
                    replyHandler(["status": "idle", "message": "Stopped collection"])
                }

            case "requestStatus":
                let status = motionManager.isCollecting ? "collecting" : "idle"
                replyHandler(["status": status])

            default:
                replyHandler(["error": "Unknown command: \(command)"])
            }
        }
    }
}
