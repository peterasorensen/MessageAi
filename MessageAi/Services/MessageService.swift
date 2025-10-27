//
//  MessageService.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions
import SwiftData

@Observable
class MessageService {
    var conversations: [Conversation] = []
    var messages: [String: [Message]] = [:] // conversationId -> messages
    var activeConversationId: String?
    var onlineUsers: [String: Bool] = [:] // userId -> isOnline

    private let db = Firestore.firestore()
    private let functions = Functions.functions()
    private var conversationListener: ListenerRegistration?
    private var messageListeners: [String: ListenerRegistration] = [:]
    private var userPresenceListeners: [String: ListenerRegistration] = [:]
    private let modelContext: ModelContext
    private let authService: AuthService
    private let translationService: TranslationService
    var aiService: AIService? // Set after initialization to avoid circular dependency

    init(modelContext: ModelContext, authService: AuthService, translationService: TranslationService) {
        self.modelContext = modelContext
        self.authService = authService
        self.translationService = translationService

        // Listen for background message delivery notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackgroundDelivery),
            name: NSNotification.Name("MarkMessageDelivered"),
            object: nil
        )
    }

    deinit {
        conversationListener?.remove()
        messageListeners.values.forEach { $0.remove() }
        userPresenceListeners.values.forEach { $0.remove() }
        NotificationCenter.default.removeObserver(self)
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
                            // Filter out conversations deleted by current user
                            if dto.deletedBy.contains(userId) {
                                print("   🗑️ Skipping deleted conversation: \(dto.id)")
                                return nil
                            }

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

    func updateGroupInfo(conversationId: String, groupName: String?, groupAvatarURL: String?) async throws {
        var updates: [String: Any] = [:]

        if let groupName = groupName {
            updates["groupName"] = groupName
        }

        if let groupAvatarURL = groupAvatarURL {
            updates["groupAvatarURL"] = groupAvatarURL
        }

        guard !updates.isEmpty else { return }

        try await db.collection("conversations")
            .document(conversationId)
            .updateData(updates)

        print("✅ Group info updated")

        // Update local conversation
        await MainActor.run {
            if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
                if let groupName = groupName {
                    conversations[index].groupName = groupName
                }
                if let groupAvatarURL = groupAvatarURL {
                    conversations[index].groupAvatarURL = groupAvatarURL
                }
                saveToLocal(conversation: conversations[index])
            }
        }
    }

    func addGroupMembers(conversationId: String, userIds: [String]) async throws {
        guard !userIds.isEmpty else { return }

        print("➕ Adding \(userIds.count) members to group: \(conversationId)")

        // Fetch user names for the new members
        var newMemberNames: [String: String] = [:]
        for userId in userIds {
            if let user = try? await authService.fetchUser(by: userId) {
                newMemberNames[userId] = user.displayName
            }
        }

        // Update Firestore
        try await db.collection("conversations")
            .document(conversationId)
            .updateData([
                "participantIds": FieldValue.arrayUnion(userIds),
                "participantNames": newMemberNames
            ])

        print("   ✅ Members added to Firestore")

        // Update local conversation
        await MainActor.run {
            if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
                conversations[index].participantIds.append(contentsOf: userIds)
                conversations[index].participantNames.merge(newMemberNames) { _, new in new }
                saveToLocal(conversation: conversations[index])
                print("   ✅ Local conversation updated")
            }
        }
    }

    func deleteConversation(conversationId: String) async throws {
        guard let currentUserId = authService.currentUser?.id else {
            throw NSError(domain: "MessageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        print("🗑️ Marking conversation as deleted for user: \(conversationId)")

        // Mark conversation as deleted in Firestore (add user to deletedBy array)
        try await db.collection("conversations")
            .document(conversationId)
            .updateData([
                "deletedBy": FieldValue.arrayUnion([currentUserId])
            ])

        print("   ✅ Marked as deleted in Firestore")

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
        print("   ✅ Conversation deleted from local storage")
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

                    // If user previously deleted this conversation, restore it by removing from deletedBy
                    if dto.deletedBy.contains(currentUserId) {
                        print("   🔄 Restoring previously deleted conversation")
                        try await db.collection("conversations")
                            .document(dto.id)
                            .updateData([
                                "deletedBy": FieldValue.arrayRemove([currentUserId])
                            ])
                    }

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

                                // Analyze and translate new message (if it's not from current user and translation is needed)
                                if message.senderId != currentUserId && message.detectedLanguage == nil {
                                    Task {
                                        await self.analyzeAndTranslateMessage(
                                            conversationId: conversationId,
                                            messageId: message.id
                                        )
                                    }
                                }
                            }

                            // Always save to local storage (updates included)
                            self.saveToLocal(message: message)
                        }
                    }

                    // Don't auto-mark as read here - only when ChatView is actively open
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

            // Update conversation's last message and increment unread count for other participants
            let conversation = conversations.first(where: { $0.id == conversationId })
            var updates: [String: Any] = [
                "lastMessage": content,
                "lastMessageTimestamp": Timestamp(date: optimisticMessage.timestamp),
                "lastMessageSenderId": currentUserId
            ]

            // Increment unread count for all participants except sender
            if let participantIds = conversation?.participantIds {
                for participantId in participantIds where participantId != currentUserId {
                    updates["unreadCount.\(participantId)"] = FieldValue.increment(Int64(1))
                }
            }

            try await db.collection("conversations")
                .document(conversationId)
                .updateData(updates)

            print("   ✅ Conversation updated with last message")

            // Send push notification to other participants via Cloud Function
            let recipientIds = conversation?.participantIds.filter { $0 != currentUserId } ?? []
            if !recipientIds.isEmpty {
                // Call the Cloud Function to send notifications
                let notificationData: [String: Any] = [
                    "recipientIds": recipientIds,
                    "title": currentUserName,
                    "body": content,
                    "conversationId": conversationId,
                    "messageId": optimisticMessage.id
                ]

                Task {
                    do {
                        let result = try await functions.httpsCallable("sendNotificationHTTP").call(notificationData)
                        if let response = result.data as? [String: Any],
                           let success = response["success"] as? Bool,
                           success {
                            print("   ✅ Push notifications sent successfully")
                        }
                    } catch {
                        print("   ⚠️ Failed to send push notification: \(error.localizedDescription)")
                        print("   💡 Make sure Cloud Functions are deployed: firebase deploy --only functions")
                    }
                }
            }

            // Check if this is an AI Pal conversation and trigger response
            if let aiPalConversationId = authService.currentUser?.aiPalConversationId,
               aiPalConversationId == conversationId {
                Task {
                    do {
                        // Trigger AI response generation via AIService
                        if let aiService = aiService {
                            try await aiService.generateAIResponse(userMessage: content, conversationId: conversationId)
                            print("   🤖 AI response generated")
                        }
                    } catch {
                        print("   ⚠️ Failed to generate AI response: \(error.localizedDescription)")
                    }
                }
            }

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
        print("📖 Marking messages as read for conversation: \(conversationId)")

        // Update local conversation unread count immediately
        await MainActor.run {
            if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
                conversations[index].unreadCount = 0
                print("   ✅ Local unread count set to 0")
            }
        }

        // Update Firestore unread count
        let conversationRef = db.collection("conversations").document(conversationId)
        try await conversationRef.updateData(["unreadCount.\(userId)": 0])
        print("   ✅ Firestore unread count set to 0")

        // Update readBy for messages
        guard let messages = messages[conversationId] else { return }

        // Update local messages immediately
        await MainActor.run {
            for (index, message) in messages.enumerated() where message.senderId != userId && !message.readBy.contains(userId) {
                self.messages[conversationId]?[index].readBy.append(userId)

                // Also save to local storage
                if let localMessage = self.messages[conversationId]?[index] {
                    self.saveToLocal(message: localMessage)
                }
            }
            print("   ✅ Updated local readBy arrays")
        }

        // Try to update Firestore (messages might be deleted due to cleanup, that's ok)
        for message in messages where message.senderId != userId && !message.readBy.contains(userId) {
            let messageRef = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(message.id)

            // Use setData with merge to avoid errors if document doesn't exist
            try? await messageRef.setData(["readBy": FieldValue.arrayUnion([userId])], merge: true)
        }
        print("   ✅ Attempted to update Firestore readBy (if messages exist)")
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

    // MARK: - Background Delivery Handler

    @objc private func handleBackgroundDelivery(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let conversationId = userInfo["conversationId"] as? String,
              let messageId = userInfo["messageId"] as? String,
              let currentUserId = authService.currentUser?.id else {
            return
        }

        print("📥 Background delivery handler called for message: \(messageId)")

        // Get conversation to access participant IDs
        guard let conversation = conversations.first(where: { $0.id == conversationId }) else {
            print("⚠️ Conversation not found for background delivery")
            return
        }

        // Mark message as delivered in Firestore
        Task {
            try? await markMessageDelivered(
                conversationId: conversationId,
                messageId: messageId,
                userId: currentUserId,
                participantIds: conversation.participantIds
            )
        }
    }

    // MARK: - Local Storage

    @MainActor
    private func saveToLocal(conversation: Conversation) {
        // Check if conversation already exists in SwiftData
        let conversationId = conversation.id
        let predicate = #Predicate<Conversation> { existingConversation in
            existingConversation.id == conversationId
        }
        let descriptor = FetchDescriptor<Conversation>(predicate: predicate)

        if let existingConversations = try? modelContext.fetch(descriptor),
           let existingConversation = existingConversations.first {
            // Update existing conversation instead of inserting
            existingConversation.lastMessage = conversation.lastMessage
            existingConversation.lastMessageTimestamp = conversation.lastMessageTimestamp
            existingConversation.lastMessageSenderId = conversation.lastMessageSenderId
            existingConversation.unreadCount = conversation.unreadCount
            existingConversation.isTyping = conversation.isTyping
            existingConversation.deletedBy = conversation.deletedBy
            existingConversation.participantNames = conversation.participantNames
        } else {
            // Insert new conversation
            modelContext.insert(conversation)
        }

        try? modelContext.save()
    }

    @MainActor
    private func saveToLocal(message: Message) {
        // Check if message already exists in SwiftData
        let messageId = message.id
        let predicate = #Predicate<Message> { existingMessage in
            existingMessage.id == messageId
        }
        let descriptor = FetchDescriptor<Message>(predicate: predicate)

        if let existingMessages = try? modelContext.fetch(descriptor),
           let existingMessage = existingMessages.first {
            // Update existing message instead of inserting
            existingMessage.content = message.content
            existingMessage.status = message.status
            existingMessage.readBy = message.readBy
            existingMessage.deliveredToUsers = message.deliveredToUsers
            existingMessage.isOptimistic = false // No longer optimistic once saved
        } else {
            // Insert new message
            modelContext.insert(message)
        }

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

    // MARK: - User Presence Tracking

    func startListeningToUserPresence(userId: String) {
        // Don't listen to our own presence
        guard userId != authService.currentUser?.id else { return }

        // Remove existing listener if any
        userPresenceListeners[userId]?.remove()

        userPresenceListeners[userId] = db.collection("users")
            .document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let data = snapshot?.data(),
                      let isOnline = data["isOnline"] as? Bool else {
                    return
                }

                Task { @MainActor in
                    self.onlineUsers[userId] = isOnline
                }
            }
    }

    func startListeningToAllParticipantsPresence() {
        // Get all unique participant IDs from conversations
        let participantIds = Set(conversations.flatMap { $0.participantIds })

        // Start listening to each participant's presence
        for participantId in participantIds {
            startListeningToUserPresence(userId: participantId)
        }
    }

    func stopListeningToUserPresence(userId: String) {
        userPresenceListeners[userId]?.remove()
        userPresenceListeners.removeValue(forKey: userId)
    }

    // MARK: - Translation

    func analyzeAndTranslateMessage(conversationId: String, messageId: String) async {
        guard let user = authService.currentUser,
              let targetLanguage = user.targetLanguage,
              let fluentLanguage = user.fluentLanguage,
              let messageIndex = messages[conversationId]?.firstIndex(where: { $0.id == messageId }),
              let message = messages[conversationId]?[messageIndex] else {
            return
        }

        print("🌍 Analyzing message for translation...")

        do {
            // First, translate the message to target language (if needed)
            let translationResult = try await translationService.analyzeMessage(
                messageText: message.content,
                targetLanguage: targetLanguage,
                fluentLanguage: fluentLanguage
            )

            let detectedLanguage = translationResult.detectedLanguage
            let translatedText = translationResult.fullTranslation

            // Now analyze the TARGET LANGUAGE text for word-by-word learning
            // This gives us word translations from target language → fluent language
            let textToAnalyze = detectedLanguage == targetLanguage ? message.content : translatedText

            print("📚 Analyzing \(targetLanguage) text for learning: \(textToAnalyze.prefix(30))...")

            let learningResult = try await translationService.analyzeMessage(
                messageText: textToAnalyze,
                targetLanguage: fluentLanguage, // Translate back to fluent language for understanding
                fluentLanguage: fluentLanguage
            )

            // Update message with translation data
            await MainActor.run {
                if let index = self.messages[conversationId]?.firstIndex(where: { $0.id == messageId }) {
                    self.messages[conversationId]?[index].detectedLanguage = detectedLanguage
                    self.messages[conversationId]?[index].translatedText = translatedText
                    // Word translations are for the target language words
                    self.messages[conversationId]?[index].setWordTranslations(learningResult.wordTranslations)

                    print("✅ Translation complete: \(detectedLanguage) → \(targetLanguage)")
                    print("✅ Learning words ready: \(learningResult.wordTranslations.count) words")
                }
            }

            // Save translation to Firestore (only if message exists)
            let encoder = JSONEncoder()
            if let wordTranslationsData = try? encoder.encode(learningResult.wordTranslations),
               let wordTranslationsJSON = String(data: wordTranslationsData, encoding: .utf8) {

                // Check if message exists in Firestore before updating
                let messageRef = db.collection("conversations")
                    .document(conversationId)
                    .collection("messages")
                    .document(messageId)

                do {
                    let snapshot = try await messageRef.getDocument()
                    if snapshot.exists {
                        let updates: [String: Any] = [
                            "detectedLanguage": detectedLanguage,
                            "translatedText": translatedText,
                            "wordTranslationsJSON": wordTranslationsJSON
                        ]
                        try await messageRef.updateData(updates)
                        print("✅ Translation saved to Firestore")
                    } else {
                        print("⏳ Message not yet in Firestore, will sync later")
                    }
                } catch {
                    print("⚠️ Could not save translation to Firestore: \(error.localizedDescription)")
                }
            }

            // Update local storage
            await MainActor.run {
                if let updatedMessage = messages[conversationId]?.first(where: { $0.id == messageId }) {
                    saveToLocal(message: updatedMessage)
                }
            }

        } catch {
            print("❌ Translation error: \(error.localizedDescription)")
        }
    }
}
