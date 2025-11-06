//
//  ContentView.swift
//  myfirstapp
//
//  Created by Andrew Smith on 11/5/25
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var connectivity = WatchConnectivityManager.shared

    var body: some View {
        NavigationView {
            VStack {
                if connectivity.receivedFiles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "applewatch.and.arrow.forward")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        Text("No files received yet")
                            .font(.headline)
                        Text("Send accelerometer data from your Watch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        Section(header: Text("Received Files (\(connectivity.receivedFiles.count))")) {
                            ForEach(connectivity.receivedFiles, id: \.self) { fileURL in
                                FileRow(fileURL: fileURL)
                            }
                            .onDelete(perform: deleteFiles)
                        }
                    }
                }
            }
            .navigationTitle("Accelerometer Data")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let fileURL = connectivity.receivedFiles[index]
            connectivity.deleteFile(at: fileURL)
        }
    }
}

struct FileRow: View {
    let fileURL: URL
    @State private var showShareSheet = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(fileURL.lastPathComponent)
                    .font(.headline)

                if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                   let size = attributes[.size] as? Int64,
                   let date = attributes[.modificationDate] as? Date {
                    Text("\(formatFileSize(size)) • \(formatDate(date))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {
                showShareSheet = true
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [fileURL])
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}
