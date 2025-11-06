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

    func transferFile(url: URL, completion: @escaping (Bool, String) -> Void) {
        guard WCSession.default.activationState == .activated else {
            completion(false, "Watch Connectivity not activated")
            return
        }

        // Transfer the file
        WCSession.default.transferFile(url, metadata: ["type": "csv"])

        completion(true, "File queued for transfer to iPhone")
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
        } else {
            print("File transfer completed successfully")

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
}
