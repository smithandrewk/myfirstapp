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
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle(fileURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData()
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
                    guard components.count == 4,
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
}

#Preview {
    NavigationView {
        GraphView(fileURL: URL(fileURLWithPath: "/tmp/sample.csv"))
    }
}
