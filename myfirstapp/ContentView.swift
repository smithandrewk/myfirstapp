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
    @StateObject private var tagManager = TagManager.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Status Section
                VStack(spacing: 8) {
                    // Collection Status
                    HStack(spacing: 8) {
                        if connectivity.isWatchCollecting {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Watch is collecting data...")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.gray)
                            Text("Ready to collect")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    // Instructions
                    Text("Use the Watch app to start and stop data collection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(Color(.systemGray6))

                Divider()

                // MARK: - File List Section
                if connectivity.files.isEmpty {
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
                        Section(header: Text("Files (\(connectivity.files.count))")) {
                            ForEach(connectivity.files) { fileItem in
                                if fileItem.status == .transferring {
                                    // Show transferring state
                                    TransferringFileRow(filename: fileItem.filename)
                                } else if let url = fileItem.url {
                                    // Show available file
                                    NavigationLink(destination: GraphView(fileURL: url)) {
                                        FileRow(fileURL: url)
                                    }
                                }
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
            let fileItem = connectivity.files[index]
            if let url = fileItem.url {
                tagManager.deleteTagsForFile(url.lastPathComponent)
                connectivity.deleteFile(at: url)
            } else {
                // Transferring file - just remove from list
                connectivity.deleteFile(named: fileItem.filename)
            }
        }
    }
}

struct TransferringFileRow: View {
    let filename: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(filename)
                    .font(.headline)
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Transferring from Watch...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .opacity(0.6)
    }
}

struct FileRow: View {
    let fileURL: URL
    @StateObject private var tagManager = TagManager.shared
    @State private var showShareSheet = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(fileURL.lastPathComponent)
                    .font(.headline)

                if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                   let size = attributes[.size] as? Int64,
                   let date = attributes[.modificationDate] as? Date {
                    Text("\(formatFileSize(size)) • \(formatDate(date))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Tags display (read-only)
                let tags = tagManager.getTags(for: fileURL.lastPathComponent).sorted()
                if !tags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            TagPillView(
                                tag: tag,
                                color: tagManager.colorForTag(tag)
                            )
                        }
                    }
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
