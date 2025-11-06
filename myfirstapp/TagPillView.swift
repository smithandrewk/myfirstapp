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
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
                .fontWeight(.medium)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.5), lineWidth: isSelected ? 2 : 1)
                )
        )
        .foregroundColor(color)
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
