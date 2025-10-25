//
//  DetailedTranslationView.swift
//  MessageAi
//
//  Created by Apple on 10/24/25.
//

import SwiftUI

struct DetailedTranslationView: View {
    @Environment(TranslationService.self) private var translationService
    @Environment(\.dismiss) private var dismiss

    let word: String
    let sourceLanguage: String
    let targetLanguage: String

    @State private var wordContext: WordContextResult?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding()
                } else if let context = wordContext {
                    VStack(alignment: .leading, spacing: 24) {
                        // Word Breakdown
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                DetailRow(label: "Root", value: context.wordBreakdown.root)
                                DetailRow(label: "Form", value: context.wordBreakdown.form)
                                DetailRow(label: "Conjugation", value: context.wordBreakdown.conjugation)
                            }
                        } header: {
                            SectionHeader(title: "Word Breakdown", icon: "text.book.closed.fill")
                        }

                        // Colloquial Meaning
                        if !context.colloquialMeaning.isEmpty {
                            Section {
                                Text(context.colloquialMeaning)
                                    .font(.body)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } header: {
                                SectionHeader(title: "Colloquial Meaning", icon: "bubble.left.fill")
                            }
                        }

                        // Multiple Meanings
                        if !context.multipleMeanings.isEmpty {
                            Section {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(context.multipleMeanings) { meaningContext in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(meaningContext.meaning)
                                                .font(.body)
                                                .fontWeight(.semibold)
                                            Text(meaningContext.context)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            } header: {
                                SectionHeader(title: "Multiple Meanings", icon: "list.bullet")
                            }
                        }

                        // Example Sentences
                        if !context.exampleSentences.isEmpty {
                            Section {
                                VStack(alignment: .leading, spacing: 16) {
                                    ForEach(context.exampleSentences) { example in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(example.original)
                                                .font(.body)
                                                .fontWeight(.medium)
                                            Text(example.translation)
                                                .font(.body)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.green.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            } header: {
                                SectionHeader(title: "Example Sentences", icon: "text.quote")
                            }
                        }
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("Failed to load word context")
                            .font(.headline)
                        Button("Retry") {
                            Task {
                                await loadWordContext()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(word)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadWordContext()
        }
    }

    private func loadWordContext() async {
        isLoading = true
        do {
            wordContext = try await translationService.expandWordContext(
                word: word,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        } catch {
            print("Error loading word context: \(error)")
        }
        isLoading = false
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.blue)
            Text(title)
                .font(.headline)
        }
        .padding(.bottom, 4)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.subheadline)
        }
    }
}
