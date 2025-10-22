//
//  MessageService.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import Foundation
import FirebaseFirestore
import SwiftData

@Observable
class MessageService {
    var conversations: [Conversation] = []
    var messages: [String: [Message]] = [:] // conversationId -> messages
    var activeConversationId: String?

    private let db = Firestore.firestore()
    private var conversationListener: ListenerRegistration?
    private var messageListeners: [String: ListenerRegistration] = [:]
    private let modelContext: ModelContext
    private let authService: AuthService

    init(modelContext: ModelContext, authService: AuthService) {
        self.modelContext = modelContext
        self.authService = authService
    }

    deinit {
        conversationListener?.remove()
        messageListeners.values.forEach { $0.remove() }
    }

    // MARK: - Conversations

    func startListeningToConversations(userId: String) {
        conversationListener?.remove()

        conversationListener = db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageTimestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("Error listening to conversations: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    self.conversations = documents.compactMap { document in
                        if let dto = try? Firestore.Decoder().decode(ConversationDTO.self, from: document.data()) {
                            let conversation = dto.toConversation(currentUserId: userId)
                            self.saveToLocal(conversation: conversation)
                            return conversation
                        }
                        return nil
                    }
                }
            }
    }

    func createConversation(with participantIds: [String], participantNames: [String: String], type: ConversationType = .oneOnOne) async throws -> Conversation {
        guard let currentUserId = authService.currentUser?.id else {
            throw NSError(domain: "MessageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        let conversation = Conversation(
            type: type,
            participantIds: participantIds,
            participantNames: participantNames
        )

        let conversationDTO = ConversationDTO(from: conversation, currentUserId: currentUserId)
        let data = try Firestore.Encoder().encode(conversationDTO)

        try await db.collection("conversations").document(conversation.id).setData(data)

        await MainActor.run {
            self.conversations.insert(conversation, at: 0)
            self.saveToLocal(conversation: conversation)
        }

        return conversation
    }

    func getOrCreateConversation(with userId: String, userName: String) async throws -> Conversation {
        guard let currentUserId = authService.currentUser?.id,
              let currentUserName = authService.currentUser?.displayName else {
            throw NSError(domain: "MessageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        // Check if conversation already exists
        if let existing = conversations.first(where: {
            $0.conversationType == .oneOnOne && $0.participantIds.contains(userId) && $0.participantIds.contains(currentUserId)
        }) {
            return existing
        }

        // Create new conversation
        let participantIds = [currentUserId, userId]
        let participantNames = [currentUserId: currentUserName, userId: userName]

        return try await createConversation(with: participantIds, participantNames: participantNames)
    }

    // MARK: - Messages

    func startListeningToMessages(conversationId: String) {
        // Remove existing listener if any
        messageListeners[conversationId]?.remove()

        messageListeners[conversationId] = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("Error listening to messages: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    // Get current messages including optimistic ones
                    let currentMessages = self.messages[conversationId] ?? []
                    let optimisticMessages = currentMessages.filter { $0.isOptimistic }

                    // Parse Firestore messages
                    let firestoreMessages = documents.compactMap { document -> Message? in
                        if let dto = try? Firestore.Decoder().decode(MessageDTO.self, from: document.data()) {
                            let message = dto.toMessage()
                            self.saveToLocal(message: message)
                            return message
                        }
                        return nil
                    }

                    // Merge: Remove optimistic messages that now exist in Firestore
                    let firestoreMessageIds = Set(firestoreMessages.map { $0.id })
                    let remainingOptimistic = optimisticMessages.filter { !firestoreMessageIds.contains($0.id) }

                    // Combine and sort by timestamp
                    self.messages[conversationId] = (firestoreMessages + remainingOptimistic)
                        .sorted { $0.timestamp < $1.timestamp }

                    // Mark messages as read
                    if let currentUserId = self.authService.currentUser?.id {
                        Task {
                            try? await self.markMessagesAsRead(conversationId: conversationId, userId: currentUserId)
                        }
                    }
                }
            }
    }

    func sendMessage(conversationId: String, content: String, type: MessageType = .text) async throws {
        guard let currentUserId = authService.currentUser?.id,
              let currentUserName = authService.currentUser?.displayName else {
            throw NSError(domain: "MessageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        // Create optimistic message
        let optimisticMessage = Message(
            conversationId: conversationId,
            senderId: currentUserId,
            senderName: currentUserName,
            content: content,
            type: type,
            status: .sending,
            isOptimistic: true
        )

        // Show optimistic message immediately
        await MainActor.run {
            if self.messages[conversationId] == nil {
                self.messages[conversationId] = []
            }
            self.messages[conversationId]?.append(optimisticMessage)
        }

        do {
            // Send to Firestore
            let messageDTO = MessageDTO(from: optimisticMessage)
            var data = try Firestore.Encoder().encode(messageDTO)
            data["status"] = MessageStatus.sent.rawValue // Update status to sent

            try await db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(optimisticMessage.id)
                .setData(data)

            // Update conversation's last message
            let updates: [String: Any] = [
                "lastMessage": content,
                "lastMessageTimestamp": Timestamp(date: optimisticMessage.timestamp),
                "lastMessageSenderId": currentUserId
            ]

            try await db.collection("conversations")
                .document(conversationId)
                .updateData(updates)

            // Listener will automatically replace optimistic message with real one

        } catch {
            // Mark message as failed
            await MainActor.run {
                if let index = self.messages[conversationId]?.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    self.messages[conversationId]?[index].status = MessageStatus.failed.rawValue
                }
            }
            throw error
        }
    }

    // MARK: - Read Receipts

    func markMessagesAsRead(conversationId: String, userId: String) async throws {
        guard let messages = messages[conversationId] else { return }

        let batch = db.batch()

        for message in messages where message.senderId != userId && !message.readBy.contains(userId) {
            let messageRef = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(message.id)

            batch.updateData(["readBy": FieldValue.arrayUnion([userId])], forDocument: messageRef)
        }

        try await batch.commit()

        // Update unread count in conversation
        let conversationRef = db.collection("conversations").document(conversationId)
        try await conversationRef.updateData(["unreadCount.\(userId)": 0])
    }

    // MARK: - Typing Indicators

    func setTyping(conversationId: String, userId: String, isTyping: Bool) async throws {
        let conversationRef = db.collection("conversations").document(conversationId)

        if isTyping {
            try await conversationRef.updateData(["isTyping": FieldValue.arrayUnion([userId])])
        } else {
            try await conversationRef.updateData(["isTyping": FieldValue.arrayRemove([userId])])
        }
    }

    // MARK: - Local Storage

    private func saveToLocal(conversation: Conversation) {
        modelContext.insert(conversation)
        try? modelContext.save()
    }

    private func saveToLocal(message: Message) {
        modelContext.insert(message)
        try? modelContext.save()
    }

    func loadLocalConversations() -> [Conversation] {
        let descriptor = FetchDescriptor<Conversation>(sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func loadLocalMessages(conversationId: String) -> [Message] {
        let predicate = #Predicate<Message> { message in
            message.conversationId == conversationId
        }
        let descriptor = FetchDescriptor<Message>(predicate: predicate, sortBy: [SortDescriptor(\.timestamp)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
