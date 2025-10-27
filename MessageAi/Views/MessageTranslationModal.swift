//
//  MessageTranslationModal.swift
//  MessageAi
//
//  Full message translation modal with sentence explanation and slang/idioms
//

import SwiftUI

struct MessageTranslationModal: View {
    @Environment(\.dismiss) private var dismiss

    let message: Message

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Original Message
                    Section {
                        Text(message.content)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } header: {
                        SectionHeader(title: "Original Message", icon: "text.bubble.fill")
                    }

                    // Translation
                    if let translation = message.translatedText {
                        Section {
                            Text(translation)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } header: {
                            SectionHeader(title: "Translation", icon: "globe")
                        }
                    }

                    // Sentence Explanation
                    if let explanation = message.sentenceExplanation, !explanation.isEmpty {
                        Section {
                            Text(explanation)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } header: {
                            SectionHeader(title: "Detailed Explanation", icon: "lightbulb.fill")
                        }
                    }

                    // Slang & Idioms
                    let slangItems = message.slangAndIdioms
                    if !slangItems.isEmpty {
                        Section {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(slangItems) { item in
                                    VStack(alignment: .leading, spacing: 12) {
                                        // Phrase
                                        HStack {
                                            Image(systemName: "quote.opening")
                                                .font(.caption)
                                                .foregroundStyle(.purple)
                                            Text(item.phrase)
                                                .font(.headline)
                                                .foregroundStyle(.purple)
                                        }

                                        // Literal vs Actual
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack(alignment: .top, spacing: 8) {
                                                Text("Literal:")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.secondary)
                                                    .frame(width: 70, alignment: .leading)
                                                Text(item.literalMeaning)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            HStack(alignment: .top, spacing: 8) {
                                                Text("Meaning:")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .frame(width: 70, alignment: .leading)
                                                Text(item.actualMeaning)
                                                    .font(.subheadline)
                                            }
                                        }

                                        // Cultural Context
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Cultural Context")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.secondary)
                                            Text(item.culturalContext)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.top, 4)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.purple.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        } header: {
                            SectionHeader(title: "Slang & Idioms", icon: "sparkles")
                        }
                    }

                    // Language & Region Info
                    if let language = message.detectedLanguage, let country = message.detectedCountry {
                        Section {
                            HStack {
                                Image(systemName: "map.fill")
                                    .foregroundStyle(.orange)
                                Text("Detected: \(languageName(language)) (\(countryName(country)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Translation Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func languageName(_ code: String) -> String {
        let locale = Locale(identifier: "en")
        return locale.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }

    private func countryName(_ code: String) -> String {
        let locale = Locale(identifier: "en")
        return locale.localizedString(forRegionCode: code) ?? code.uppercased()
    }
}

#Preview {
    MessageTranslationModal(
        message: Message(
            conversationId: "123",
            senderId: "user1",
            senderName: "John",
            content: "¿Qué onda güey?",
            detectedLanguage: "es",
            detectedCountry: "MX",
            translatedText: "What's up dude?",
            sentenceExplanation: "This is a very casual Mexican Spanish greeting used among friends."
        )
    )
}
