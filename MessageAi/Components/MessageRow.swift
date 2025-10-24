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

    private var actualStatus: MessageStatus {
        // For optimistic messages, use their status
        if message.isOptimistic {
            return message.messageStatus
        }

        // Check read status first
        if !message.readBy.isEmpty {
            return .read
        }

        // Check delivery status
        let deliveredCount = message.deliveredToUsers.count
        if deliveredCount >= totalParticipants {
            return .delivered
        } else if deliveredCount > 0 {
            return .sent
        }

        return message.messageStatus
    }

    var body: some View {
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
                HStack(alignment: .bottom, spacing: 4) {
                    if isFromCurrentUser {
                        messageStatusIndicator
                    }

                    Text(message.content)
                        .font(.system(size: 16))
                        .foregroundStyle(isFromCurrentUser ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(messageBubbleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                // Timestamp
                Text(formatTimestamp(message.timestamp))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }

            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 12)
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
            } else if actualStatus == .sent {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .transition(.scale.combined(with: .opacity))
            } else if actualStatus == .delivered {
                HStack(spacing: -3) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .transition(.scale.combined(with: .opacity))
            } else if actualStatus == .read {
                HStack(spacing: -3) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.blue)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 16)
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
            totalParticipants: 2
        )

        MessageRow(
            message: Message(
                conversationId: "1",
                senderId: "2",
                senderName: "Me",
                content: "I'm doing great, thanks!",
                status: .delivered
            ),
            isFromCurrentUser: true,
            showSenderName: false,
            isRead: true,
            totalParticipants: 2
        )
    }
    .padding()
}
