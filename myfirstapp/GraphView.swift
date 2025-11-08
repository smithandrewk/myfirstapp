//
//  GraphView.swift
//  myfirstapp
//
//  Created by Andrew Smith
//

import SwiftUI
import Charts

struct AccelerometerDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Double
    let x: Double
    let y: Double
    let z: Double
}

struct GraphView: View {
    let fileURL: URL

    @State private var dataPoints: [AccelerometerDataPoint] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @StateObject private var tagManager = TagManager.shared
    @State private var selectedTags: Set<String> = []
    @State private var newTagText: String = ""
    @State private var showingAddField: Bool = false
    @State private var tagToDelete: String?
    @State private var showingDeleteAlert = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading data...")
                    .padding()
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Error Loading Data")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if dataPoints.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No Data")
                        .font(.headline)
                    Text("The file appears to be empty")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Data info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Data Points: \(dataPoints.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Duration: \(formatDuration())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)

                        // Chart
                        Chart {
                            ForEach(dataPoints) { point in
                                LineMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value("Acceleration", point.x),
                                    series: .value("Axis", "X")
                                )
                                .foregroundStyle(.red)

                                LineMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value("Acceleration", point.y),
                                    series: .value("Axis", "Y")
                                )
                                .foregroundStyle(.green)

                                LineMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value("Acceleration", point.z),
                                    series: .value("Axis", "Z")
                                )
                                .foregroundStyle(.blue)
                            }
                        }
                        .chartYAxisLabel("Acceleration (g)")
                        .chartXAxisLabel("Time (s)")
                        .frame(height: 300)
                        .padding()

                        // Legend
                        HStack(spacing: 24) {
                            Label("X-Axis", systemImage: "circle.fill")
                                .foregroundColor(.red)
                            Label("Y-Axis", systemImage: "circle.fill")
                                .foregroundColor(.green)
                            Label("Z-Axis", systemImage: "circle.fill")
                                .foregroundColor(.blue)
                        }
                        .font(.caption)
                        .padding(.horizontal)

                        Divider()
                            .padding(.vertical)

                        // Tags section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tags")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            if !tagManager.allTags.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(Array(tagManager.allTags).sorted(), id: \.self) { tag in
                                        TagPillView(
                                            tag: tag,
                                            color: tagManager.colorForTag(tag),
                                            isSelected: selectedTags.contains(tag)
                                        )
                                        .onTapGesture {
                                            toggleTag(tag)
                                        }
                                        .onLongPressGesture(minimumDuration: 0.5) {
                                            tagToDelete = tag
                                            showingDeleteAlert = true
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }

                            // Add new tag
                            if showingAddField {
                                HStack {
                                    TextField("Enter tag name", text: $newTagText)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .autocapitalization(.none)
                                        .focused($isTextFieldFocused)

                                    Button(action: addNewTag) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                    }
                                    .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                    Button(action: {
                                        showingAddField = false
                                        newTagText = ""
                                        isTextFieldFocused = false
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal)
                            } else {
                                Button(action: {
                                    showingAddField = true
                                    isTextFieldFocused = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add New Tag")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom)
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle(fileURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData()
            selectedTags = Set(tagManager.getTags(for: fileURL.lastPathComponent))
        }
        .alert("Delete Tag", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                tagToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let tag = tagToDelete {
                    deleteTag(tag)
                }
                tagToDelete = nil
            }
        } message: {
            if let tag = tagToDelete {
                Text("Are you sure you want to delete '\(tag)' from all files?")
            }
        }
    }

    private func loadData() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let csvString = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = csvString.components(separatedBy: .newlines)

                var points: [AccelerometerDataPoint] = []

                // Skip header line and parse data
                for line in lines.dropFirst() {
                    let components = line.components(separatedBy: ",")
                    // Support both 4-column (old format) and 5-column (new format with Source)
                    guard components.count >= 4,
                          let timestamp = Double(components[0]),
                          let x = Double(components[1]),
                          let y = Double(components[2]),
                          let z = Double(components[3]) else {
                        continue
                    }

                    points.append(AccelerometerDataPoint(
                        timestamp: timestamp,
                        x: x,
                        y: y,
                        z: z
                    ))
                }

                // Normalize timestamps to start from 0
                if let firstTimestamp = points.first?.timestamp {
                    points = points.map { point in
                        AccelerometerDataPoint(
                            timestamp: point.timestamp - firstTimestamp,
                            x: point.x,
                            y: point.y,
                            z: point.z
                        )
                    }
                }

                // Interpolate if dataset is too large
                let interpolatedPoints = interpolateData(points, targetCount: 500)

                DispatchQueue.main.async {
                    self.dataPoints = interpolatedPoints
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func interpolateData(_ data: [AccelerometerDataPoint], targetCount: Int) -> [AccelerometerDataPoint] {
        guard data.count > targetCount else {
            return data
        }

        var result: [AccelerometerDataPoint] = []
        let step = Double(data.count - 1) / Double(targetCount - 1)

        for i in 0..<targetCount {
            let index = step * Double(i)
            let lowerIndex = Int(floor(index))
            let upperIndex = min(lowerIndex + 1, data.count - 1)
            let fraction = index - Double(lowerIndex)

            let lower = data[lowerIndex]
            let upper = data[upperIndex]

            let interpolatedPoint = AccelerometerDataPoint(
                timestamp: lower.timestamp + (upper.timestamp - lower.timestamp) * fraction,
                x: lower.x + (upper.x - lower.x) * fraction,
                y: lower.y + (upper.y - lower.y) * fraction,
                z: lower.z + (upper.z - lower.z) * fraction
            )

            result.append(interpolatedPoint)
        }

        return result
    }

    private func formatDuration() -> String {
        guard let first = dataPoints.first?.timestamp,
              let last = dataPoints.last?.timestamp else {
            return "N/A"
        }

        let duration = last - first

        if duration < 60 {
            return String(format: "%.1f seconds", duration)
        } else if duration < 3600 {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        } else {
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
        saveTags()
    }

    private func addNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        tagManager.addTag(trimmed)
        selectedTags.insert(trimmed)
        newTagText = ""
        showingAddField = false
        saveTags()
    }

    private func saveTags() {
        tagManager.setTags(Array(selectedTags), for: fileURL.lastPathComponent)
    }

    private func deleteTag(_ tag: String) {
        // Remove from current file's selection
        selectedTags.remove(tag)
        saveTags()

        // Delete from global library
        tagManager.deleteTag(tag)
    }
}

#Preview {
    NavigationView {
        GraphView(fileURL: URL(fileURLWithPath: "/tmp/sample.csv"))
    }
}
