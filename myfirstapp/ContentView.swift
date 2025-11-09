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
            ZStack {
                // Background
                Color.dsBackgroundSecondary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Status Section
                    GlassCard(padding: Spacing.md) {
                        VStack(spacing: Spacing.sm) {
                            HStack(spacing: Spacing.sm) {
                                if connectivity.isWatchCollecting {
                                    StatusBadge(
                                        text: "Collecting Data",
                                        icon: "wave.3.right",
                                        color: .dsSuccess,
                                        isAnimating: true
                                    )
                                } else {
                                    StatusBadge(
                                        text: "Ready",
                                        icon: "checkmark.circle.fill",
                                        color: .dsSecondary
                                    )
                                }

                                Spacer()

                                Image(systemName: "applewatch")
                                    .font(.title3)
                                    .foregroundColor(.dsAccent)
                            }

                            Text("Use the Watch app to start and stop data collection")
                                .font(.dsCaption)
                                .foregroundColor(.dsSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)

                    // MARK: - File List Section
                    if connectivity.files.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "applewatch.radiowaves.left.and.right",
                            title: "No Data Yet",
                            subtitle: "Send accelerometer data from your Apple Watch to get started",
                            iconColor: .blue
                        )
                        Spacer()
                    } else {
                        VStack(spacing: 0) {
                            // Section Header
                            HStack {
                                Text("Files")
                                    .font(.dsHeadline)
                                Spacer()
                                Text("\(connectivity.files.count)")
                                    .font(.dsCallout)
                                    .foregroundColor(.dsSecondary)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.dsAccent.opacity(0.12))
                                    )
                            }
                            .padding(.horizontal, Spacing.md)
                            .padding(.top, Spacing.md)
                            .padding(.bottom, Spacing.sm)

                            // File List
                            List {
                                ForEach(connectivity.files) { fileItem in
                                    if fileItem.status == .transferring {
                                        TransferringFileCard(filename: fileItem.filename)
                                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                    } else if let url = fileItem.url {
                                        ZStack {
                                            NavigationLink(destination: GraphView(fileURL: url)) {
                                                EmptyView()
                                            }
                                            .opacity(0)

                                            FileCard(fileURL: url)
                                        }
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                deleteFile(url: url, filename: fileItem.filename)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                    }
                }
            }
            .navigationTitle("Accelerometer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func deleteFile(url: URL, filename: String) {
        tagManager.deleteTagsForFile(filename)
        connectivity.deleteFile(at: url)
    }
}

struct TransferringFileCard: View {
    let filename: String

    var body: some View {
        ModernCard(shadow: .subtle) {
            HStack(spacing: Spacing.md) {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(Color.dsAccent.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(filename)
                        .font(.dsCallout)
                        .foregroundColor(.dsPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Transferring from Watch...")
                            .font(.dsCaption)
                            .foregroundColor(.dsSecondary)
                    }
                }

                Spacer()
            }
        }
        .opacity(0.8)
    }
}

struct FileCard: View {
    let fileURL: URL
    @StateObject private var tagManager = TagManager.shared
    @StateObject private var connectivity = WatchConnectivityManager.shared
    @State private var showShareSheet = false

    var body: some View {
        ModernCard(shadow: .medium) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.dsAccent.opacity(0.2), Color.purple.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)

                        Image(systemName: "waveform.path.ecg")
                            .font(.title2)
                            .foregroundColor(.dsAccent)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(fileURL.lastPathComponent)
                            .font(.dsCallout)
                            .foregroundColor(.dsPrimary)
                            .lineLimit(2)

                        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                           let size = attributes[.size] as? Int64,
                           let date = attributes[.modificationDate] as? Date {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.caption2)
                                Text(formatFileSize(size))
                                Text("•")
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(formatDate(date))
                            }
                            .font(.dsSmall)
                            .foregroundColor(.dsSecondary)
                        }
                    }

                    Spacer()

                    // Share button
                    Button(action: {
                        showShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.dsAccent)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.dsAccent.opacity(0.1))
                            )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }

                // Duration
                if let elapsedTime = connectivity.getElapsedTime(for: fileURL.lastPathComponent) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "timer")
                            .font(.caption)
                        Text("Duration: \(formatDuration(elapsedTime))")
                            .font(.dsCaption)
                    }
                    .foregroundColor(.dsWarning)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.dsWarning.opacity(0.12))
                    )
                }

                // Tags
                let tags = tagManager.getTags(for: fileURL.lastPathComponent).sorted()
                if !tags.isEmpty {
                    FlowLayout(spacing: Spacing.xs) {
                        ForEach(tags, id: \.self) { tag in
                            TagPillView(
                                tag: tag,
                                color: tagManager.colorForTag(tag)
                            )
                        }
                    }
                }
            }
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

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
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
