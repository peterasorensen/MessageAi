//
//  WordTooltipOverlay.swift
//  MessageAi
//
//  Created by Apple on 10/24/25.
//

import SwiftUI

struct WordTooltipOverlay: View {
    @Environment(AuthService.self) private var authService
    @Environment(TTSService.self) private var ttsService

    let wordTranslation: WordTranslation
    let wordPosition: CGRect
    let onDismiss: () -> Void
    let onShowDetails: () -> Void
    let message: Message? // Optional message for caching word audio

    @State private var tooltipPosition: TooltipPosition = .below

    enum TooltipPosition {
        case above, below
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dismiss background
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            onDismiss()
                        }
                    }

                // Tooltip card positioned relative to word
                VStack(spacing: 0) {
                    // Arrow pointing to word (when below)
                    if tooltipPosition == .below {
                        Triangle()
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .frame(width: 20, height: 10)
                            .offset(x: calculateArrowOffset(in: geometry), y: 0)
                    }

                    // Tooltip content
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                // Translation (larger, blue) with audio button
                                HStack(spacing: 8) {
                                    Text(wordTranslation.originalWord)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                    // TTS play button for word - right next to translation
                                    Button {
                                        Task {
                                            await playWordAudio()
                                        }
                                    } label: {
                                        Image(systemName: isPlayingWord ? "stop.circle.fill" : "speaker.wave.2.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.blue)
                                            .symbolEffect(.pulse, options: .repeating, isActive: isPlayingWord)
                                    }
                                    .buttonStyle(.plain)
                                }

                            // Original word (smaller, secondary)
                            Text(wordTranslation.translation)
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            
                            }
                            Spacer(minLength: 12)
                            Button {
                                withAnimation {
                                    onDismiss()
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(wordTranslation.partOfSpeech)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(Capsule())

                        Button {
                            onShowDetails()
                        } label: {
                            HStack(spacing: 6) {
                                Text("More details")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .foregroundStyle(.blue)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .shadow(color: .black.opacity(0.3), radius: 15, y: 5)
                    )

                    // Arrow pointing to word (when above)
                    if tooltipPosition == .above {
                        Triangle()
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .frame(width: 20, height: 10)
                            .rotationEffect(.degrees(180))
                            .offset(x: calculateArrowOffset(in: geometry), y: 0)
                    }
                }
                .frame(width: 280)
                .position(x: calculateTooltipX(in: geometry), y: calculateTooltipY(in: geometry))
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .onAppear {
                    updateTooltipPosition(geometry: geometry)
                }
                .onChange(of: wordPosition) { _, _ in
                    updateTooltipPosition(geometry: geometry)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    private func calculateTooltipX(in geometry: GeometryProxy) -> CGFloat {
        let tooltipWidth: CGFloat = 280
        let screenWidth = geometry.size.width

        // Try to center tooltip on word, but keep it on screen
        var x = wordPosition.midX

        // Keep tooltip within screen bounds (with 16pt padding)
        let minX = tooltipWidth / 2 + 16
        let maxX = screenWidth - tooltipWidth / 2 - 16

        x = min(max(x, minX), maxX)

        return x
    }

    private func calculateTooltipY(in geometry: GeometryProxy) -> CGFloat {
        let tooltipHeight: CGFloat = 170 // Approximate
        let arrowHeight: CGFloat = 10
        let spacing: CGFloat = 2

        if tooltipPosition == .below {
            // Position tooltip below word
            // Tooltip center Y = word bottom + arrow + spacing (uses your working calculation)
            return wordPosition.maxY - arrowHeight - spacing
        } else {
            // Position tooltip above word
            // Tooltip center Y = word top - arrow - spacing - tooltip height (uses your working calculation)
            return wordPosition.minY - arrowHeight - spacing - tooltipHeight
        }
    }

    private func calculateArrowOffset(in geometry: GeometryProxy) -> CGFloat {
        // Arrow offset from tooltip center to point at word
        let tooltipCenterX = calculateTooltipX(in: geometry)
        return wordPosition.midX - tooltipCenterX
    }

    private func updateTooltipPosition(geometry: GeometryProxy) {
        // Determine if tooltip should be above or below word based on screen position
        let screenMid = geometry.size.height / 2
        let wordMid = wordPosition.midY
        tooltipPosition = wordMid < screenMid ? .below : .above
    }

    // MARK: - TTS Playback

    private var isPlayingWord: Bool {
        ttsService.isPlaying && ttsService.playingWord == wordTranslation.originalWord
    }

    private func playWordAudio() async {
        // Stop if currently playing this word
        if isPlayingWord {
            ttsService.stopAudio()
            return
        }

        // Get target language for pronunciation
        let targetLanguage = authService.currentUser?.targetLanguage ?? "en"

        // Get user's preferred voice
        let voice = authService.currentUser?.preferredTTSVoice ?? "nova"

        do {
            try await ttsService.playWordAudio(
                word: wordTranslation.originalWord,
                language: targetLanguage,
                voice: voice,
                message: message
            )
        } catch {
            print("❌ Failed to play word audio: \(error)")
        }
    }
}

// Triangle shape for tooltip arrow
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
