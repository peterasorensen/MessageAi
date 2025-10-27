//
//  TappableMessageText.swift
//  MessageAi
//
//  Created by Apple on 10/24/25.
//

import SwiftUI

struct TappableMessageText: View {
    @Environment(WordTranslationState.self) private var wordTranslationState

    let text: String // Target language text (with word translations for learning)
    let displayText: String // What to actually display
    let originalText: String? // Original text to show alongside translation
    let wordTranslations: [WordTranslation]
    let detectedLanguage: String?
    let targetLanguage: String?
    let fluentLanguage: String?
    let isFromCurrentUser: Bool
    let showOriginal: Bool // If true, showing original alongside translation
    let message: Message? // For TTS audio caching

    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 6) {
            if !isFromCurrentUser && !wordTranslations.isEmpty {
                // Show tappable target language words (for learning)
                tappableWordsView
            } else {
                // Show regular text (current user's messages)
                Text(displayText)
                    .font(.system(size: 16))
                    .foregroundStyle(isFromCurrentUser ? .white : .primary)
            }

            // Show original text below if toggled and it's different from displayed
            if showOriginal, let original = originalText, original != text && !original.isEmpty {
                Divider()
                    .background(Color.secondary.opacity(0.3))
                    .padding(.horizontal, 4)

                Text(original)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
    }

    private var tappableWordsView: some View {
        // Target language words with tappable translations
        WrappingHStack(spacing: 4, lineSpacing: 2) {
            ForEach(Array(text.split(separator: " ", omittingEmptySubsequences: false).enumerated()), id: \.offset) { index, word in
                let wordString = String(word)
                let wordTranslation = findTranslationForWord(wordString)

                if !wordString.isEmpty {
                    GeometryReader { geometry in
                        Button {
                            if let translation = wordTranslation {
                                withAnimation(.spring(response: 0.3)) {
                                    wordTranslationState.selectWord(
                                        translation,
                                        at: geometry.frame(in: .global),
                                        targetLanguage: targetLanguage,
                                        fluentLanguage: fluentLanguage,
                                        message: message
                                    )
                                }
                            }
                        } label: {
                            Text(wordString)
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)
                                .underline(wordTranslation != nil, color: .blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(wordTranslation == nil)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(width: wordWidth(for: wordString), height: 22)
                }
            }
        }
    }

    private func wordWidth(for word: String) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 16)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (word as NSString).size(withAttributes: attributes)
        return size.width
    }

    private func findTranslationForWord(_ word: String) -> WordTranslation? {
        let cleanWord = word.trimmingCharacters(in: .punctuationCharacters).lowercased()

        // Try exact match first
        if let translation = wordTranslations.first(where: {
            $0.originalWord.lowercased() == cleanWord
        }) {
            return translation
        }

        // Try contains match
        if let translation = wordTranslations.first(where: {
            $0.originalWord.lowercased().contains(cleanWord) ||
            cleanWord.contains($0.originalWord.lowercased())
        }) {
            return translation
        }

        return nil
    }
}

// Custom wrapping layout for text
struct WrappingHStack: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let frame = result.frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.replacingUnspecifiedDimensions().width
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && x > 0 {
                // Move to next line
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }

            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
        }

        let totalHeight = y + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}
