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
        print("🔥 Starting conversation listener for user: \(userId)")
        conversationListener?.remove()

        conversationListener = db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageTimestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Error listening to conversations: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ No conversation documents")
                    return
                }

                print("💬 Received \(documents.count) conversations from Firestore")

                Task { @MainActor in
                    self.conversations = documents.compactMap { document in
                        if let dto = try? Firestore.Decoder().decode(ConversationDTO.self, from: document.data()) {
                            let conversation = dto.toConversation(currentUserId: userId)
                            self.saveToLocal(conversation: conversation)
                            print("   📝 Conversation: \(conversation.id) with \(conversation.otherParticipantName(currentUserId: userId))")
                            return conversation
                        }
                        return nil
                    }
                    print("   ✅ Total conversations loaded: \(self.conversations.count)")
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

    func deleteConversation(conversationId: String) async throws {
        // Local-only deletion (like iMessage)
        // Does NOT delete from Firestore (other user still sees conversation)

        print("🗑️ Deleting conversation locally: \(conversationId)")

        // Remove message listener
        messageListeners[conversationId]?.remove()
        messageListeners.removeValue(forKey: conversationId)

        // Remove from local memory
        await MainActor.run {
            conversations.removeAll { $0.id == conversationId }
            messages.removeValue(forKey: conversationId)
        }

        // Delete from local storage (SwiftData)
        let conversationPredicate = #Predicate<Conversation> { conversation in
            conversation.id == conversationId
        }
        let conversationDescriptor = FetchDescriptor<Conversation>(predicate: conversationPredicate)
        if let localConversations = try? modelContext.fetch(conversationDescriptor) {
            localConversations.forEach { modelContext.delete($0) }
        }

        let messagePredicate = #Predicate<Message> { message in
            message.conversationId == conversationId
        }
        let messageDescriptor = FetchDescriptor<Message>(predicate: messagePredicate)
        if let localMessages = try? modelContext.fetch(messageDescriptor) {
            localMessages.forEach { modelContext.delete($0) }
        }

        try? modelContext.save()
        print("   ✅ Conversation deleted from local device only")
    }

    func getOrCreateConversation(with userId: String, userName: String) async throws -> Conversation {
        guard let currentUserId = authService.currentUser?.id,
              let currentUserName = authService.currentUser?.displayName else {
            throw NSError(domain: "MessageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        // Check if conversation already exists locally
        if let existing = conversations.first(where: {
            $0.conversationType == .oneOnOne &&
            $0.participantIds.sorted() == [currentUserId, userId].sorted()
        }) {
            print("✅ Found existing conversation locally: \(existing.id)")
            return existing
        }

        // Check Firestore for existing conversation
        let snapshot = try await db.collection("conversations")
            .whereField("participantIds", arrayContains: currentUserId)
            .whereField("type", isEqualTo: ConversationType.oneOnOne.rawValue)
            .getDocuments()

        // Look for conversation with these exact two participants
        for document in snapshot.documents {
            if let dto = try? Firestore.Decoder().decode(ConversationDTO.self, from: document.data()) {
                let participantSet = Set(dto.participantIds)
                if participantSet == Set([currentUserId, userId]) {
                    print("✅ Found existing conversation in Firestore: \(dto.id)")
                    let conversation = dto.toConversation(currentUserId: currentUserId)

                    // Add to local cache
                    await MainActor.run {
                        if !self.conversations.contains(where: { $0.id == conversation.id }) {
                            self.conversations.append(conversation)
                            self.saveToLocal(conversation: conversation)
                        }
                    }

                    return conversation
                }
            }
        }

        // No existing conversation found, create new one
        print("📝 Creating new conversation")
        let participantIds = [currentUserId, userId]
        let participantNames = [currentUserId: currentUserName, userId: userName]

        return try await createConversation(with: participantIds, participantNames: participantNames)
    }

    // MARK: - Messages

    func startListeningToMessages(conversationId: String) {
        guard let currentUserId = authService.currentUser?.id else { return }

        print("🔥 Starting message listener for conversation: \(conversationId)")

        // Load all messages from SwiftData first (instant display)
        let localMessages = loadLocalMessages(conversationId: conversationId)
        Task { @MainActor in
            self.messages[conversationId] = localMessages
            print("📱 Loaded \(localMessages.count) messages from local storage")
        }

        // Get latest message timestamp from local storage
        // Use Date(timeIntervalSince1970: 0) instead of Date.distantPast to avoid Firestore timestamp errors
        let latestTimestamp = localMessages.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date(timeIntervalSince1970: 0)

        // Remove existing listener if any
        messageListeners[conversationId]?.remove()

        // Listen to ALL messages for this conversation (to get delivery/read updates)
        // Note: We're listening to all messages, not just new ones, to catch deliveredToUsers and readBy updates
        messageListeners[conversationId] = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Error listening to messages: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                print("📨 Received \(documents.count) messages from Firestore")

                Task { @MainActor in
                    for document in documents {
                        if let dto = try? Firestore.Decoder().decode(MessageDTO.self, from: document.data()) {
                            let message = dto.toMessage()

                            // Update existing message or add new one
                            if self.messages[conversationId] == nil {
                                self.messages[conversationId] = []
                            }

                            if let index = self.messages[conversationId]!.firstIndex(where: { $0.id == message.id }) {
                                // Update existing message (for delivery/read updates)
                                self.messages[conversationId]![index].deliveredToUsers = message.deliveredToUsers
                                self.messages[conversationId]![index].readBy = message.readBy
                                self.messages[conversationId]![index].status = message.status
                                print("   🔄 Updated message: \(message.id)")
                            } else {
                                // New message - add it
                                self.messages[conversationId]!.append(message)
                                self.messages[conversationId]!.sort { $0.timestamp < $1.timestamp }
                                print("   ➕ Added message: \(message.id)")

                                // Mark as delivered to this user (for new messages only)
                                Task {
                                    try? await self.markMessageDelivered(
                                        conversationId: conversationId,
                                        messageId: message.id,
                                        userId: currentUserId,
                                        participantIds: self.conversations.first(where: { $0.id == conversationId })?.participantIds ?? []
                                    )
                                }
                            }

                            // Always save to local storage (updates included)
                            self.saveToLocal(message: message)
                        }
                    }

                    // Mark messages as read
                    Task {
                        try? await self.markMessagesAsRead(conversationId: conversationId, userId: currentUserId)
                    }
                }
            }
    }

    func sendMessage(conversationId: String, content: String, type: MessageType = .text) async throws {
        guard let currentUserId = authService.currentUser?.id,
              let currentUserName = authService.currentUser?.displayName else {
            throw NSError(domain: "MessageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        print("📤 Sending message to conversation: \(conversationId)")

        // Create optimistic message
        let optimisticMessage = Message(
            conversationId: conversationId,
            senderId: currentUserId,
            senderName: currentUserName,
            content: content,
            type: type,
            status: .sending,
            deliveredToUsers: [currentUserId], // Sender has it immediately
            isOptimistic: true
        )

        // Show optimistic message immediately & save to local storage
        await MainActor.run {
            if self.messages[conversationId] == nil {
                self.messages[conversationId] = []
            }
            self.messages[conversationId]?.append(optimisticMessage)
            self.saveToLocal(message: optimisticMessage)
            print("   ✅ Added optimistic message locally")
        }

        do {
            // Send to Firestore
            let messageDTO = MessageDTO(from: optimisticMessage)
            var data = try Firestore.Encoder().encode(messageDTO)
            data["status"] = MessageStatus.sent.rawValue // Update status to sent
            data["deliveredToUsers"] = [currentUserId] // Sender has it

            try await db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(optimisticMessage.id)
                .setData(data)

            print("   ✅ Message saved to Firestore: \(optimisticMessage.id)")

            // Update conversation's last message
            let updates: [String: Any] = [
                "lastMessage": content,
                "lastMessageTimestamp": Timestamp(date: optimisticMessage.timestamp),
                "lastMessageSenderId": currentUserId
            ]

            try await db.collection("conversations")
                .document(conversationId)
                .updateData(updates)

            print("   ✅ Conversation updated with last message")

            // Listener will automatically replace optimistic message with real one

        } catch {
            print("   ❌ Failed to send message: \(error.localizedDescription)")

            // Mark message as failed
            await MainActor.run {
                if let index = self.messages[conversationId]?.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    self.messages[conversationId]?[index].status = MessageStatus.failed.rawValue
                }
            }
            throw error
        }
    }

    // MARK: - Delivery Tracking & Cleanup

    func markMessageDelivered(conversationId: String, messageId: String, userId: String, participantIds: [String]) async throws {
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)

        // Add current user to deliveredToUsers
        try await messageRef.updateData(["deliveredToUsers": FieldValue.arrayUnion([userId])])

        print("   📥 Marked message \(messageId) as delivered to \(userId)")

        // Check if all participants have received the message
        try await cleanupDeliveredMessage(
            conversationId: conversationId,
            messageId: messageId,
            participantIds: participantIds
        )
    }

    private func cleanupDeliveredMessage(conversationId: String, messageId: String, participantIds: [String]) async throws {
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)

        // Fetch current message to check delivery status
        let document = try await messageRef.getDocument()
        guard let data = document.data(),
              let deliveredToUsers = data["deliveredToUsers"] as? [String] else {
            return
        }

        // If all participants have received the message, delete from Firestore
        let deliveredSet = Set(deliveredToUsers)
        let participantSet = Set(participantIds)

        if deliveredSet == participantSet {
            try await messageRef.delete()
            print("   🗑️ Deleted message \(messageId) from Firestore (all users delivered)")
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
