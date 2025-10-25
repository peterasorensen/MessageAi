//
//  MessageRow.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import SwiftUI

struct MessageRow: View {
    let message: Message
    let isFromCurrentUser: Bool
    let showSenderName: Bool
    let isRead: Bool
    let totalParticipants: Int
    let participantNames: [String: String] // userId -> name mapping
    let messagesOffset: CGFloat
    let forceShowTimestamp: Bool

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

                    // Message bubble
                    Text(message.content)
                        .font(.system(size: 16))
                        .foregroundStyle(isFromCurrentUser ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(messageBubbleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

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
            forceShowTimestamp: false
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
            forceShowTimestamp: false
        )
    }
    .padding()
}
