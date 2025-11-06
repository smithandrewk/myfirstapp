//
//  TagEditorSheet.swift
//  myfirstapp
//
//  Created by Andrew Smith
//

import SwiftUI

struct TagEditorSheet: View {
    let filename: String
    @ObservedObject var tagManager: TagManager
    @Binding var isPresented: Bool

    @State private var selectedTags: Set<String> = []
    @State private var newTagText: String = ""
    @State private var showingAddField: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tags
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !tagManager.allTags.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Tap to select tags")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                FlowLayout(spacing: 8) {
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
                                    }
                                }
                            }
                            .padding()
                        }

                        // Add new tag section
                        VStack(alignment: .leading, spacing: 12) {
                            if showingAddField {
                                VStack(spacing: 12) {
                                    HStack {
                                        TextField("Enter tag name", text: $newTagText)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .autocapitalization(.none)

                                        Button(action: addNewTag) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.blue)
                                        }
                                        .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                        Button(action: {
                                            showingAddField = false
                                            newTagText = ""
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            } else {
                                Button(action: {
                                    showingAddField = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add New Tag")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .onAppear {
                selectedTags = Set(tagManager.getTags(for: filename))
            }
            .onDisappear {
                saveTags()
            }
            .navigationTitle("Tag File")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDragIndicator(.visible)
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    private func addNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        tagManager.addTag(trimmed)
        selectedTags.insert(trimmed)
        newTagText = ""
        showingAddField = false
    }

    private func saveTags() {
        tagManager.setTags(Array(selectedTags), for: filename)
    }
}

#Preview {
    TagEditorSheet(filename: "test.csv", tagManager: TagManager.shared, isPresented: .constant(true))
}
