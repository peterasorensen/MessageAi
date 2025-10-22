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
            if message.messageStatus == .sending {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, options: .repeating)
            } else if message.messageStatus == .failed {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .symbolEffect(.bounce, value: message.messageStatus)
            } else if message.messageStatus == .sent {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .transition(.scale.combined(with: .opacity))
            } else if message.messageStatus == .delivered {
                HStack(spacing: -3) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .transition(.scale.combined(with: .opacity))
            } else if message.messageStatus == .read || isRead {
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
        .animation(.easeInOut(duration: 0.2), value: message.messageStatus)
        .animation(.easeInOut(duration: 0.2), value: isRead)
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
            isRead: false
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
            isRead: true
        )
    }
    .padding()
}
