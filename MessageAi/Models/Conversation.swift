//
//  Conversation.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import Foundation
import SwiftData

enum ConversationType: String, Codable {
    case oneOnOne
    case group
}

@Model
final class Conversation {
    @Attribute(.unique) var id: String
    var type: String // ConversationType raw value
    var participantIds: [String]
    var participantNames: [String: String] // userId -> displayName mapping
    var lastMessage: String
    var lastMessageTimestamp: Date
    var lastMessageSenderId: String
    var unreadCount: Int
    var isTyping: [String] // Array of user IDs who are currently typing
    var deletedBy: [String] // Array of user IDs who deleted this conversation
    var createdAt: Date
    var groupName: String? // For group chats
    var groupAvatarURL: String? // For group chats

    init(
        id: String = UUID().uuidString,
        type: ConversationType = .oneOnOne,
        participantIds: [String],
        participantNames: [String: String] = [:],
        lastMessage: String = "",
        lastMessageTimestamp: Date = Date(),
        lastMessageSenderId: String = "",
        unreadCount: Int = 0,
        isTyping: [String] = [],
        deletedBy: [String] = [],
        createdAt: Date = Date(),
        groupName: String? = nil,
        groupAvatarURL: String? = nil
    ) {
        self.id = id
        self.type = type.rawValue
        self.participantIds = participantIds
        self.participantNames = participantNames
        self.lastMessage = lastMessage
        self.lastMessageTimestamp = lastMessageTimestamp
        self.lastMessageSenderId = lastMessageSenderId
        self.unreadCount = unreadCount
        self.isTyping = isTyping
        self.deletedBy = deletedBy
        self.createdAt = createdAt
        self.groupName = groupName
        self.groupAvatarURL = groupAvatarURL
    }

    var conversationType: ConversationType {
        ConversationType(rawValue: type) ?? .oneOnOne
    }

    func otherParticipantId(currentUserId: String) -> String? {
        participantIds.first { $0 != currentUserId }
    }

    func otherParticipantName(currentUserId: String) -> String {
        if conversationType == .group {
            return groupName ?? "Group Chat"
        }
        if let otherId = otherParticipantId(currentUserId: currentUserId) {
            return participantNames[otherId] ?? "Unknown"
        }
        return "Unknown"
    }
}

// Firestore DTO for sync
struct ConversationDTO: Codable {
    let id: String
    let type: String
    let participantIds: [String]
    let participantNames: [String: String]
    let lastMessage: String
    let lastMessageTimestamp: Date
    let lastMessageSenderId: String
    let unreadCount: [String: Int] // userId -> unread count mapping
    let isTyping: [String]
    let deletedBy: [String] // Array of user IDs who deleted this conversation
    let createdAt: Date
    let groupName: String?
    let groupAvatarURL: String?

    init(from conversation: Conversation, currentUserId: String) {
        self.id = conversation.id
        self.type = conversation.type
        self.participantIds = conversation.participantIds
        self.participantNames = conversation.participantNames
        self.lastMessage = conversation.lastMessage
        self.lastMessageTimestamp = conversation.lastMessageTimestamp
        self.lastMessageSenderId = conversation.lastMessageSenderId
        self.unreadCount = [currentUserId: conversation.unreadCount]
        self.isTyping = conversation.isTyping
        self.deletedBy = conversation.deletedBy
        self.createdAt = conversation.createdAt
        self.groupName = conversation.groupName
        self.groupAvatarURL = conversation.groupAvatarURL
    }

    func toConversation(currentUserId: String) -> Conversation {
        return Conversation(
            id: id,
            type: ConversationType(rawValue: type) ?? .oneOnOne,
            participantIds: participantIds,
            participantNames: participantNames,
            lastMessage: lastMessage,
            lastMessageTimestamp: lastMessageTimestamp,
            lastMessageSenderId: lastMessageSenderId,
            unreadCount: unreadCount[currentUserId] ?? 0,
            isTyping: isTyping,
            deletedBy: deletedBy,
            createdAt: createdAt,
            groupName: groupName,
            groupAvatarURL: groupAvatarURL
        )
    }
}
