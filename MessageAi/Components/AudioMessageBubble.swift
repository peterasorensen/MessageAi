//
//  AudioMessageBubble.swift
//  MessageAi
//
//  Audio message with transcription preview and expansion
//

import SwiftUI

struct AudioMessageBubble: View {
    @Environment(AuthService.self) private var authService
    let message: Message
    @State private var showFullTranscription = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Audio player controls
            if let audioURL = message.audioFileURL,
               let url = URL(string: audioURL) {
                AudioPlayerControls(
                    audioURL: url,
                    waveformSamples: message.waveformSamples,
                    duration: message.audioDuration ?? 0
                )
            }

            // Transcription section
            if message.isTranscriptionReady {
                transcriptionView
            } else {
                transcriptionLoadingView
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .sheet(isPresented: $showFullTranscription) {
            TranscriptionModal(message: message)
        }
    }

    @ViewBuilder
    private var transcriptionView: some View {
        if let transcription = message.audioTranscription, !transcription.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Transcription header
                HStack {
                    Image(systemName: "text.quote")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Transcription")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                // Truncated transcription preview (3 lines max)
                if message.audioTranscriptionWordTranslations.isEmpty {
                    // Plain text if no word translations yet
                    Text(transcription)
                        .font(.system(size: 14))
                        .lineLimit(3)
                } else {
                    // Tappable words for translation
                    TappableMessageText(
                        text: transcription,
                        displayText: transcription,
                        originalText: nil,
                        wordTranslations: message.audioTranscriptionWordTranslations,
                        detectedLanguage: message.audioTranscriptionLanguage,
                        targetLanguage: authService.currentUser?.targetLanguage,
                        fluentLanguage: authService.currentUser?.fluentLanguage,
                        isFromCurrentUser: false,
                        showOriginal: false,
                        message: message
                    )
                    .lineLimit(3)
                }

                // "Show more" button if text is longer
                if transcription.count > 100 || transcription.components(separatedBy: "\n").count > 3 {
                    Button(action: {
                        showFullTranscription = true
                    }) {
                        HStack(spacing: 4) {
                            Text("Show more")
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var transcriptionLoadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Transcribing...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}

#Preview {
    AudioMessageBubble(
        message: Message(
            conversationId: "123",
            senderId: "user1",
            senderName: "John",
            content: "",
            type: .audio,
            audioFileURL: "/tmp/test.m4a",
            audioDuration: 45.0,
            audioTranscription: "This is a test transcription.",
            isTranscriptionReady: true
        )
    )
    .environment(AuthService())
    .padding()
}
