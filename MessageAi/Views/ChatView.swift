//
//  ChatView.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import SwiftUI
import SwiftData
import FirebaseFirestore

struct ChatView: View {
    let conversation: Conversation
    let authService: AuthService
    let messageService: MessageService

    @State private var messageText = ""
    @State private var isTyping = false
    @State private var showingGroupInfo = false
    @FocusState private var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    @State private var otherUser: User?
    @State private var userListener: ListenerRegistration?
    @State private var messagesOffset: CGFloat = 0
    @State private var showAllTimestamps = false
    private let maxSwipeOffset: CGFloat = 60

    private var messages: [Message] {
        messageService.messages[conversation.id] ?? []
    }

    private var currentUserId: String {
        authService.currentUser?.id ?? ""
    }

    private var otherUserId: String? {
        conversation.participantIds.first { $0 != currentUserId }
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
                                isRead: message.readBy.contains(currentUserId),
                                totalParticipants: conversation.participantIds.count,
                                participantNames: conversation.participantNames,
                                messagesOffset: messagesOffset,
                                forceShowTimestamp: showAllTimestamps
                            )
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }

                        // Typing indicator (only show if OTHER users are typing)
                        if !conversation.isTyping.isEmpty && !conversation.isTyping.contains(currentUserId) {
                            typingIndicator
                                .id("typing")
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.top, 8)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: messages.count)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            let translation = value.translation.width
                            if translation < 0 {  // Only allow left swipe
                                messagesOffset = max(translation, -maxSwipeOffset)
                                if abs(translation) > 30 {
                                    showAllTimestamps = true
                                }
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                messagesOffset = 0
                                showAllTimestamps = false
                            }
                        }
                )
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
                Button(action: {
                    if conversation.conversationType == .group {
                        showingGroupInfo = true
                    }
                }) {
                    VStack(spacing: 2) {
                        Text(conversation.otherParticipantName(currentUserId: currentUserId))
                            .font(.headline)

                        if !conversation.isTyping.isEmpty && !conversation.isTyping.contains(currentUserId) {
                            Text("typing...")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else if conversation.conversationType == .group {
                            Text("\(conversation.participantIds.count) members")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let otherUser = otherUser {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(otherUser.isOnline ? Color.green : Color.gray)
                                    .frame(width: 6, height: 6)
                                Text(otherUser.isOnline ? "Online" : "Offline")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(conversation.conversationType != .group)
            }
        }
        .sheet(isPresented: $showingGroupInfo) {
            GroupInfoView(
                conversation: conversation,
                authService: authService,
                messageService: messageService
            )
        }
        .onAppear {
            messageService.activeConversationId = conversation.id
            messageService.startListeningToMessages(conversationId: conversation.id)

            // Fetch other user's profile and listen for online status updates
            if let otherUserId = otherUserId {
                Task {
                    await loadOtherUser(userId: otherUserId)
                }
            }

            // Mark messages as read when opening chat
            Task {
                try? await messageService.markMessagesAsRead(conversationId: conversation.id, userId: currentUserId)
            }
        }
        .onChange(of: messages.count) { _, _ in
            // Mark messages as read when new messages arrive while viewing
            if messageService.activeConversationId == conversation.id {
                Task {
                    try? await messageService.markMessagesAsRead(conversationId: conversation.id, userId: currentUserId)
                }
            }
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

            // Remove user listener
            userListener?.remove()
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

    private func loadOtherUser(userId: String) async {
        // Set up real-time listener for user status
        await MainActor.run {
            userListener = authService.listenToUser(userId: userId) { user in
                self.otherUser = user
            }
        }
    }
}

#Preview {
    let authService = AuthService()
    return NavigationStack {
        ChatView(
            conversation: Conversation(
                participantIds: ["1", "2"],
                participantNames: ["1": "Me", "2": "John Doe"],
                lastMessage: "Hey there!"
            ),
            authService: authService,
            messageService: MessageService(
                modelContext: ModelContext(
                    try! ModelContainer(for: Conversation.self, Message.self, User.self)
                ),
                authService: authService
            )
        )
    }
}
