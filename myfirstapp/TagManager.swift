//
//  TagManager.swift
//  myfirstapp
//
//  Created by Andrew Smith
//

import Foundation
import SwiftUI

class TagManager: ObservableObject {
    static let shared = TagManager()

    @Published var allTags: Set<String> = []
    @Published var fileTags: [String: [String]] = [:] // filename -> [tags]

    private var tagColorIndices: [String: Int] = [:] // tag -> color index

    private let allTagsKey = "com.myfirstapp.allTags"
    private let fileTagsKey = "com.myfirstapp.fileTags"
    private let tagColorIndicesKey = "com.myfirstapp.tagColorIndices"

    // Apple-like color palette for tags
    let tagColors: [Color] = [
        Color(red: 1.0, green: 0.59, blue: 0.0),    // Orange
        Color(red: 0.35, green: 0.34, blue: 0.84),  // Purple
        Color(red: 1.0, green: 0.18, blue: 0.33),   // Pink
        Color(red: 0.0, green: 0.78, blue: 1.0),    // Cyan
        Color(red: 0.2, green: 0.78, blue: 0.35),   // Green
        Color(red: 1.0, green: 0.8, blue: 0.0),     // Yellow
        Color(red: 0.0, green: 0.48, blue: 1.0),    // Blue
        Color(red: 0.65, green: 0.13, blue: 0.95),  // Indigo
    ]

    private init() {
        loadTags()
    }

    // MARK: - Persistence

    private func loadTags() {
        if let tagsData = UserDefaults.standard.array(forKey: allTagsKey) as? [String] {
            allTags = Set(tagsData)
        }

        if let fileTagsData = UserDefaults.standard.dictionary(forKey: fileTagsKey) as? [String: [String]] {
            fileTags = fileTagsData
        }

        if let colorIndicesData = UserDefaults.standard.dictionary(forKey: tagColorIndicesKey) as? [String: Int] {
            tagColorIndices = colorIndicesData
        }
    }

    private func saveTags() {
        UserDefaults.standard.set(Array(allTags), forKey: allTagsKey)
        UserDefaults.standard.set(fileTags, forKey: fileTagsKey)
        UserDefaults.standard.set(tagColorIndices, forKey: tagColorIndicesKey)
    }

    // MARK: - Tag Management

    func addTag(_ tag: String) {
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else { return }

        allTags.insert(trimmedTag)

        // Assign a color if this tag doesn't have one
        if tagColorIndices[trimmedTag] == nil {
            // Use the next available color index
            let usedIndices = Set(tagColorIndices.values)
            var nextIndex = 0
            for i in 0..<tagColors.count {
                if !usedIndices.contains(i) {
                    nextIndex = i
                    break
                }
            }
            // If all colors are used, cycle through them
            if usedIndices.count >= tagColors.count {
                nextIndex = tagColorIndices.count % tagColors.count
            }
            tagColorIndices[trimmedTag] = nextIndex
        }

        saveTags()
    }

    func getTags(for filename: String) -> [String] {
        return fileTags[filename] ?? []
    }

    func setTags(_ tags: [String], for filename: String) {
        fileTags[filename] = tags

        // Add new tags to global library and assign colors
        for tag in tags {
            addTag(tag)
        }

        saveTags()
    }

    func removeTag(_ tag: String, from filename: String) {
        fileTags[filename]?.removeAll { $0 == tag }
        saveTags()
    }

    func colorForTag(_ tag: String) -> Color {
        // Use persistent color index, or assign one if it doesn't exist
        if let colorIndex = tagColorIndices[tag] {
            return tagColors[colorIndex % tagColors.count]
        } else {
            // Shouldn't happen, but assign a color just in case
            addTag(tag)
            return tagColors[tagColorIndices[tag] ?? 0]
        }
    }

    func deleteTagsForFile(_ filename: String) {
        fileTags.removeValue(forKey: filename)
        saveTags()
    }

    func deleteTag(_ tag: String) {
        // Remove from global library
        allTags.remove(tag)

        // Remove from all files
        for (filename, tags) in fileTags {
            if tags.contains(tag) {
                fileTags[filename] = tags.filter { $0 != tag }
            }
        }

        // Remove color assignment
        tagColorIndices.removeValue(forKey: tag)

        saveTags()
    }
}
