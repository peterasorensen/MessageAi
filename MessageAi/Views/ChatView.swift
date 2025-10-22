//
//  ChatView.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    let conversation: Conversation
    let authService: AuthService
    let messageService: MessageService

    @State private var messageText = ""
    @State private var isTyping = false
    @FocusState private var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?

    private var messages: [Message] {
        messageService.messages[conversation.id] ?? []
    }

    private var currentUserId: String {
        authService.currentUser?.id ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages, id: \.id) { message in
                            MessageRow(
                                message: message,
                                isFromCurrentUser: message.senderId == currentUserId,
                                showSenderName: conversation.conversationType == .group,
                                isRead: message.readBy.contains(currentUserId)
                            )
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }

                        // Typing indicator
                        if !conversation.isTyping.isEmpty {
                            typingIndicator
                                .id("typing")
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.top, 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: messages.count)
                }
                .onAppear {
                    scrollProxy = proxy
                    scrollToBottom(animated: false)
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(animated: true)
                }
            }

            // Input bar
            MessageInputBar(
                text: $messageText,
                isFocused: $isInputFocused,
                onSend: sendMessage,
                onTypingChanged: handleTypingChanged
            )
        }
        .navigationTitle(conversation.otherParticipantName(currentUserId: currentUserId))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversation.otherParticipantName(currentUserId: currentUserId))
                        .font(.headline)

                    if !conversation.isTyping.isEmpty {
                        Text("typing...")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .onAppear {
            messageService.activeConversationId = conversation.id
            messageService.startListeningToMessages(conversationId: conversation.id)
        }
        .onDisappear {
            messageService.activeConversationId = nil

            // Stop typing indicator
            if isTyping {
                Task {
                    try? await messageService.setTyping(
                        conversationId: conversation.id,
                        userId: currentUserId,
                        isTyping: false
                    )
                }
            }
        }
    }

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.0)
                        .animation(
                            Animation
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: UUID()
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        Task {
            do {
                try await messageService.sendMessage(
                    conversationId: conversation.id,
                    content: trimmedText
                )

                // Add haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()

                // Scroll to bottom
                scrollToBottom(animated: true)
            } catch {
                print("Error sending message: \(error.localizedDescription)")
            }
        }
    }

    private func handleTypingChanged(_ typing: Bool) {
        guard typing != isTyping else { return }
        isTyping = typing

        Task {
            try? await messageService.setTyping(
                conversationId: conversation.id,
                userId: currentUserId,
                isTyping: typing
            )
        }
    }

    private func scrollToBottom(animated: Bool) {
        guard let proxy = scrollProxy else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(animated ? .easeOut(duration: 0.3) : nil) {
                if let lastMessage = messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                } else if !conversation.isTyping.isEmpty {
                    proxy.scrollTo("typing", anchor: .bottom)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(
            conversation: Conversation(
                participantIds: ["1", "2"],
                participantNames: ["1": "Me", "2": "John Doe"],
                lastMessage: "Hey there!"
            ),
            authService: AuthService(),
            messageService: MessageService(
                modelContext: ModelContext(
                    try! ModelContainer(for: Conversation.self, Message.self, User.self)
                ),
                authService: AuthService()
            )
        )
    }
}
