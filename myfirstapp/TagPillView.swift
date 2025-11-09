//
//  TagPillView.swift
//  myfirstapp
//
//  Created by Andrew Smith
//

import SwiftUI

struct TagPillView: View {
    let tag: String
    let color: Color
    let isSelected: Bool

    init(tag: String, color: Color, isSelected: Bool = false) {
        self.tag = tag
        self.color = color
        self.isSelected = isSelected
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(tag)
                .font(.dsCaption)
                .fontWeight(.semibold)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            ZStack {
                // Base background
                Capsule()
                    .fill(color.opacity(isSelected ? 0.2 : 0.12))

                // Selected gradient overlay
                if isSelected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.3), color.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Border
                Capsule()
                    .stroke(
                        color.opacity(isSelected ? 0.6 : 0.3),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        )
        .foregroundColor(isSelected ? color : color.opacity(0.8))
        .shadow(
            color: isSelected ? color.opacity(0.3) : .clear,
            radius: isSelected ? 4 : 0,
            y: isSelected ? 2 : 0
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .contentShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        TagPillView(tag: "drinking coffee", color: .orange, isSelected: false)
        TagPillView(tag: "brushing teeth", color: .blue, isSelected: true)
        TagPillView(tag: "walking", color: .green, isSelected: false)
    }
    .padding()
}
