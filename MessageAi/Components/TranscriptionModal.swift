//
//  TranscriptionModal.swift
//  MessageAi
//
//  Full transcription view with audio replay and word tooltips
//

import SwiftUI

struct TranscriptionModal: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    let message: Message

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Audio player at top for replay while reading
                    if let audioURL = message.audioFileURL,
                       let url = URL(string: audioURL) {
                        AudioPlayerControls(
                            audioURL: url,
                            waveformSamples: message.waveformSamples,
                            duration: message.audioDuration ?? 0
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    Divider()

                    // Full transcription with tappable words
                    if let transcription = message.audioTranscription {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Full Transcription")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)

                            if message.audioTranscriptionWordTranslations.isEmpty {
                                // Plain text if no word translations
                                Text(transcription)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.primary)
                            } else {
                                // Tappable words with translations
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
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Audio Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TranscriptionModal(
        message: Message(
            conversationId: "123",
            senderId: "user1",
            senderName: "John",
            content: "",
            type: .audio,
            audioFileURL: "/tmp/test.m4a",
            audioDuration: 125.0,
            audioTranscription: "This is a test transcription.",
            isTranscriptionReady: true
        )
    )
    .environment(AuthService())
}
