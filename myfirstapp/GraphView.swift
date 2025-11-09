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
        ZStack {
            Color.dsBackgroundSecondary
                .ignoresSafeArea()

            if isLoading {
                VStack(spacing: Spacing.md) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading data...")
                        .font(.dsCallout)
                        .foregroundColor(.dsSecondary)
                }
            } else if let error = errorMessage {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Error Loading Data",
                    subtitle: error,
                    iconColor: .orange
                )
            } else if dataPoints.isEmpty {
                EmptyStateView(
                    icon: "chart.xyaxis.line",
                    title: "No Data",
                    subtitle: "The file appears to be empty",
                    iconColor: .gray
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        // Data info card
                        ModernCard(shadow: .subtle) {
                            HStack(spacing: Spacing.lg) {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text("Data Points")
                                        .font(.dsSmall)
                                        .foregroundColor(.dsSecondary)
                                    Text("\(dataPoints.count)")
                                        .font(.dsHeadline)
                                        .foregroundColor(.dsAccent)
                                }

                                Divider()
                                    .frame(height: 30)

                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text("Duration")
                                        .font(.dsSmall)
                                        .foregroundColor(.dsSecondary)
                                    Text(formatDuration())
                                        .font(.dsHeadline)
                                        .foregroundColor(.dsAccent)
                                }

                                Spacer()
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.md)

                        // Chart card
                        ModernCard(padding: Spacing.md) {
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                Text("Acceleration Data")
                                    .font(.dsHeadline)

                                Chart {
                                    ForEach(dataPoints) { point in
                                        LineMark(
                                            x: .value("Time", point.timestamp),
                                            y: .value("Acceleration", point.x),
                                            series: .value("Axis", "X")
                                        )
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.red.opacity(0.8), .red],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )

                                        LineMark(
                                            x: .value("Time", point.timestamp),
                                            y: .value("Acceleration", point.y),
                                            series: .value("Axis", "Y")
                                        )
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.green.opacity(0.8), .green],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )

                                        LineMark(
                                            x: .value("Time", point.timestamp),
                                            y: .value("Acceleration", point.z),
                                            series: .value("Axis", "Z")
                                        )
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.blue.opacity(0.8), .blue],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                    }
                                }
                                .chartYAxisLabel("Acceleration (g)")
                                .chartXAxisLabel("Time (s)")
                                .frame(height: 280)

                                // Legend
                                HStack(spacing: Spacing.lg) {
                                    HStack(spacing: Spacing.xs) {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 8, height: 8)
                                        Text("X-Axis")
                                            .font(.dsCaption)
                                    }
                                    HStack(spacing: Spacing.xs) {
                                        Circle()
                                            .fill(.green)
                                            .frame(width: 8, height: 8)
                                        Text("Y-Axis")
                                            .font(.dsCaption)
                                    }
                                    HStack(spacing: Spacing.xs) {
                                        Circle()
                                            .fill(.blue)
                                            .frame(width: 8, height: 8)
                                        Text("Z-Axis")
                                            .font(.dsCaption)
                                    }
                                }
                                .foregroundColor(.dsSecondary)
                            }
                        }
                        .padding(.horizontal, Spacing.md)

                        // Tags section
                        ModernCard {
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                Text("Tags")
                                    .font(.dsHeadline)
                                    .foregroundColor(.dsPrimary)

                                if !tagManager.allTags.isEmpty {
                                    FlowLayout(spacing: Spacing.xs) {
                                        ForEach(Array(tagManager.allTags).sorted(), id: \.self) { tag in
                                            Button(action: {
                                                toggleTag(tag)
                                            }) {
                                                TagPillView(
                                                    tag: tag,
                                                    color: tagManager.colorForTag(tag),
                                                    isSelected: selectedTags.contains(tag)
                                                )
                                            }
                                            .buttonStyle(ScaleButtonStyle())
                                            .simultaneousGesture(
                                                LongPressGesture(minimumDuration: 0.5)
                                                    .onEnded { _ in
                                                        tagToDelete = tag
                                                        showingDeleteAlert = true
                                                    }
                                            )
                                        }
                                    }
                                }

                                // Add new tag
                                if showingAddField {
                                    VStack(spacing: Spacing.xs) {
                                        TextField("Enter tag name", text: $newTagText)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .autocapitalization(.none)
                                            .focused($isTextFieldFocused)

                                        HStack(spacing: Spacing.sm) {
                                            Button(action: {
                                                showingAddField = false
                                                newTagText = ""
                                                isTextFieldFocused = false
                                            }) {
                                                Text("Cancel")
                                                    .font(.dsCallout)
                                                    .foregroundColor(.dsSecondary)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, Spacing.sm)
                                                    .background(Color.dsBackgroundTertiary)
                                                    .cornerRadius(CornerRadius.sm)
                                            }

                                            Button(action: addNewTag) {
                                                Text("Add Tag")
                                                    .font(.dsCallout)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, Spacing.sm)
                                                    .background(
                                                        LinearGradient(
                                                            colors: [.blue, .purple],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        )
                                                    )
                                                    .cornerRadius(CornerRadius.sm)
                                            }
                                            .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                            .opacity(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                                        }
                                    }
                                } else {
                                    Button(action: {
                                        showingAddField = true
                                        isTextFieldFocused = true
                                    }) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Add New Tag")
                                        }
                                        .font(.dsCallout)
                                        .foregroundColor(.dsAccent)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, Spacing.sm)
                                        .background(Color.dsAccent.opacity(0.1))
                                        .cornerRadius(CornerRadius.sm)
                                    }
                                    .pressableScale()
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.md)
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle(fileURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
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
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedTags.contains(tag) {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
            }
        }
        saveTags()
    }

    private func addNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation {
            tagManager.addTag(trimmed)
            selectedTags.insert(trimmed)
            newTagText = ""
            showingAddField = false
        }
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
