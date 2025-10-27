//
//  MessageRow.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import SwiftUI

struct MessageRow: View {
    @Environment(AuthService.self) private var authService
    @Environment(TTSService.self) private var ttsService

    let message: Message
    let isFromCurrentUser: Bool
    let showSenderName: Bool
    let isRead: Bool
    let totalParticipants: Int
    let participantNames: [String: String] // userId -> name mapping
    let messagesOffset: CGFloat
    let forceShowTimestamp: Bool
    let autoTranslateEnabled: Bool

    @State private var showOriginal = false

    private var actualStatus: MessageStatus {
        // For optimistic messages, use their status
        if message.isOptimistic {
            return message.messageStatus
        }

        // Check read status first - but only if OTHER users (not sender) have read it
        let readByOthers = message.readBy.filter { $0 != message.senderId }
        if !readByOthers.isEmpty {
            return .read
        }

        // In group chats (3+ participants), skip delivered status
        // Go directly from sent to read (shown as profile pictures)
        if totalParticipants > 2 {
            return .sent
        }

        // For 1-on-1 chats, check delivery status
        let deliveredCount = message.deliveredToUsers.count
        if deliveredCount >= totalParticipants {
            return .delivered
        } else if deliveredCount > 0 {
            return .sent
        }

        return message.messageStatus
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Timestamp layer - always rendered at fixed position on right
            HStack {
                Spacer()
                Text(formatTimestamp(message.timestamp))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
                    .padding(.trailing, 8)
            }

            // Message content layer - slides left to reveal timestamp
            HStack(alignment: .bottom, spacing: 8) {
                if isFromCurrentUser {
                    Spacer(minLength: 60)
                }

                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                    // Sender name (for group chats)
                    if showSenderName && !isFromCurrentUser {
                        Text(message.senderName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 12)
                    }

                    // Message bubble with TTS button (for received messages)
                    HStack(spacing: 8) {
                        if !isFromCurrentUser && shouldShowTTSButton {
                            // Play button on the left for received messages (only when TTS is available)
                            ttsPlayButton
                        }

                        // Message bubble with popover support
                        messageBubbleContent

                        if !isFromCurrentUser {
                            // Spacer to push bubble left
                            Spacer(minLength: 0)
                        }
                    }

                    // Translation toggle (if translation available)
                    if hasTranslation {
                        Button {
                            showOriginal.toggle()
                        } label: {
                            Text(showOriginal ? "Hide original" : "Show original")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                    }

                    // Status indicator below bubble (for sent messages only)
                    if isFromCurrentUser {
                        HStack(spacing: 4) {
                            messageStatusIndicator
                        }
                        .padding(.horizontal, 12)
                    }
                }

                if !isFromCurrentUser {
                    Spacer(minLength: 60)
                }
            }
            .padding(.horizontal, 12)
            .offset(x: messagesOffset)
            .background(
                messagesOffset == 0 ?
                    Color(uiColor: .systemBackground) :
                    Color(uiColor: .systemBackground).opacity(0.3)
            )
        }
        .padding(.vertical, 2)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Subviews

    private var messageBubbleContent: some View {
        ZStack {
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Check if this is an audio message
                if message.messageType == .audio {
                    // Audio message bubble
                    AudioMessageBubble(message: message)
                } else {
                    // Regular text message bubble
                    TappableMessageText(
                        text: textForWordTapping,
                        displayText: displayedText,
                        originalText: hasTranslation ? message.content : nil,
                        wordTranslations: message.wordTranslations,
                        detectedLanguage: message.detectedLanguage,
                        targetLanguage: authService.currentUser?.targetLanguage,
                        fluentLanguage: authService.currentUser?.fluentLanguage,
                        isFromCurrentUser: isFromCurrentUser,
                        showOriginal: showOriginal,
                        message: message
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(messageBubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private var ttsPlayButton: some View {
        Button {
            Task {
                await playMessageAudio()
            }
        } label: {
            Image(systemName: isCurrentlyPlaying ? "stop.circle.fill" : "play.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, options: .repeating, isActive: isCurrentlyPlaying)
        }
        .buttonStyle(.plain)
    }

    private var isCurrentlyPlaying: Bool {
        ttsService.isPlaying && ttsService.playingMessageId == message.id
    }

    private var hasTranslation: Bool {
        message.translatedText != nil && !message.translatedText!.isEmpty
    }

    /// Determines if TTS should be available for this message
    /// TTS is available when:
    /// 1. Message is already in target language (detectedLanguage == targetLanguage), OR
    /// 2. Translation has arrived (hasTranslation)
    private var shouldShowTTSButton: Bool {
        guard let targetLang = authService.currentUser?.targetLanguage else {
            return false
        }

        // Case 1: Message is already in target language
        if let detectedLang = message.detectedLanguage,
           detectedLang == targetLang {
            return true
        }

        // Case 2: Translation has arrived
        if hasTranslation {
            return true
        }

        return false
    }

    private var displayedText: String {
        if hasTranslation && autoTranslateEnabled && !showOriginal {
            return message.translatedText ?? message.content
        }
        return message.content
    }

    // Text that contains the word translations (target language text for learning)
    private var textForWordTapping: String {
        // If message was translated to target language, use the translation
        // Otherwise use the original content (it's already in target language)
        if let detectedLang = message.detectedLanguage,
           let targetLang = authService.currentUser?.targetLanguage,
           detectedLang != targetLang,
           let translated = message.translatedText {
            return translated
        }
        return message.content
    }

    private var messageBubbleBackground: some View {
        Group {
            if isFromCurrentUser {
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color(uiColor: .systemGray5)
            }
        }
    }

    private var messageStatusIndicator: some View {
        Group {
            if actualStatus == .sending {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, options: .repeating)
            } else if actualStatus == .failed {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .symbolEffect(.bounce, value: actualStatus)
            } else if actualStatus == .read && !message.readBy.isEmpty {
                // Show profile pictures of users who read the message (excluding sender)
                let readByOthers = message.readBy.filter { $0 != message.senderId }
                if !readByOthers.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(readByOthers.prefix(3), id: \.self) { userId in
                            AvatarView(
                                name: participantNames[userId] ?? "?",
                                size: 14
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color(uiColor: .systemBackground), lineWidth: 1.5)
                            )
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            } else if actualStatus == .delivered {
                Text("Delivered")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if actualStatus == .sent {
                Text("Sent")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: actualStatus)
        .animation(.easeInOut(duration: 0.2), value: message.deliveredToUsers.count)
        .animation(.easeInOut(duration: 0.2), value: message.readBy.count)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday " + date.formatted(date: .omitted, time: .shortened)
        } else {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
    }

    // MARK: - TTS Playback

    private func playMessageAudio() async {
        // Stop if currently playing this message
        if isCurrentlyPlaying {
            ttsService.stopAudio()
            return
        }

        let targetLang = authService.currentUser?.targetLanguage ?? "en"
        let detectedLang = message.detectedLanguage

        // Determine which text and language to play
        let textToPlay: String
        let language: String

        // Case 1: Message is already in target language - play original text
        if detectedLang == targetLang {
            textToPlay = message.content
            language = targetLang
            print("🎯 Message already in target language - playing original")
        }
        // Case 2: Showing translated text - play translation in target language
        else if hasTranslation && autoTranslateEnabled && !showOriginal {
            textToPlay = message.translatedText ?? message.content
            language = targetLang
            print("🌍 Playing translated text in target language")
        }
        // Case 3: Showing original text in non-target language - play in detected language
        else {
            textToPlay = message.content
            language = detectedLang ?? targetLang
            print("📝 Playing original text in detected language")
        }

        // Determine voice
        let voice = ttsService.getVoiceForSender(
            senderId: message.senderId,
            aiPersonaType: authService.currentUser?.aiPersonaType,
            userPreference: authService.currentUser?.preferredTTSVoice
        )

        do {
            try await ttsService.playMessageAudio(
                message: message,
                text: textToPlay,
                language: language,
                voice: voice
            )
        } catch {
            print("❌ Failed to play message audio: \(error)")
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        MessageRow(
            message: Message(
                conversationId: "1",
                senderId: "1",
                senderName: "John",
                content: "Hey! How are you?",
                status: .read
            ),
            isFromCurrentUser: false,
            showSenderName: false,
            isRead: false,
            totalParticipants: 2,
            participantNames: ["1": "John", "2": "Me"],
            messagesOffset: 0,
            forceShowTimestamp: false,
            autoTranslateEnabled: false
        )

        MessageRow(
            message: Message(
                conversationId: "1",
                senderId: "2",
                senderName: "Me",
                content: "I'm doing great, thanks!",
                status: .delivered,
                readBy: ["1"]
            ),
            isFromCurrentUser: true,
            showSenderName: false,
            isRead: true,
            totalParticipants: 2,
            participantNames: ["1": "John", "2": "Me"],
            messagesOffset: 0,
            forceShowTimestamp: false,
            autoTranslateEnabled: false
        )
    }
    .padding()
}
