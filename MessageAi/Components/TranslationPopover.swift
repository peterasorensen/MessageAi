//
//  TranslationPopover.swift
//  MessageAi
//
//  Created by Apple on 10/24/25.
//

import SwiftUI

struct TranslationPopover: View {
    let wordTranslation: WordTranslation
    let onExpand: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(wordTranslation.translation)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(wordTranslation.partOfSpeech)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onExpand) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .frame(maxWidth: 200)
    }
}

struct TranslatableText: View {
    let message: Message
    @State private var selectedWordTranslation: WordTranslation?
    @State private var tapLocation: CGPoint = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(message.content)
                .font(.system(size: 16))
                .multilineTextAlignment(.leading)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                TapGesture()
                                    .onEnded { value in
                                        // Find word at tap location
                                        if let wordTranslation = findWordAtLocation(geometry: geometry) {
                                            selectedWordTranslation = wordTranslation
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        tapLocation = value.location
                                    }
                            )
                    }
                )

            // Popover positioned above tapped word
            if let wordTranslation = selectedWordTranslation {
                TranslationPopover(
                    wordTranslation: wordTranslation,
                    onExpand: {
                        // Will trigger DetailedTranslationView
                        // This will be handled by parent view
                    }
                )
                .position(x: tapLocation.x, y: max(tapLocation.y - 40, 30))
                .transition(.scale.combined(with: .opacity))
                .zIndex(100)
                .onTapGesture {
                    // Keep popover visible when tapping inside it
                }
            }
        }
    }

    private func findWordAtLocation(geometry: GeometryProxy) -> WordTranslation? {
        // Simplified word finding - in real app would use proper text layout
        let wordTranslations = message.wordTranslations

        // For now, return random word translation for demonstration
        // In production, calculate exact word position based on tapLocation
        return wordTranslations.first
    }
}
