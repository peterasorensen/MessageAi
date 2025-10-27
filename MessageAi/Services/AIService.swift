//
//  AIService.swift
//  MessageAi
//
//  Created by Apple on 10/26/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

@Observable
class AIService {
    private let db = Firestore.firestore()
    private let functions = Functions.functions()
    private let messageService: MessageService
    private let authService: AuthService

    // System user ID for AI pal
    static let AI_PAL_USER_ID = "ai-pal-system"

    init(messageService: MessageService, authService: AuthService) {
        self.messageService = messageService
        self.authService = authService
    }

    // MARK: - AI Pal Initialization

    func initializeAIPal() async throws {
        print("🤖 initializeAIPal called")
        guard let user = authService.currentUser,
              let persona = user.aiPersona,
              let targetLanguage = user.targetLanguage else {
            print("❌ Missing required data: user=\(authService.currentUser != nil), persona=\(authService.currentUser?.aiPersona != nil), targetLang=\(authService.currentUser?.targetLanguage != nil)")
            return
        }

        // Check if AI pal conversation already exists
        if user.aiPalConversationId != nil {
            print("ℹ️ AI pal conversation already exists: \(user.aiPalConversationId!)")
            return
        }

        print("✅ Starting AI pal initialization for user: \(user.id), persona: \(persona.rawValue)")

        // Create conversation with AI pal
        let conversation = Conversation(
            id: UUID().uuidString,
            type: .oneOnOne,
            participantIds: [user.id, AIService.AI_PAL_USER_ID],
            participantNames: [
                user.id: user.displayName,
                AIService.AI_PAL_USER_ID: user.aiPalDisplayName
            ],
            createdAt: Date()
        )

        // Save conversation
        let conversationData: [String: Any] = [
            "id": conversation.id,
            "type": conversation.type,
            "participantIds": conversation.participantIds,
            "participantNames": conversation.participantNames,
            "lastMessage": conversation.lastMessage,
            "lastMessageTimestamp": Timestamp(date: conversation.lastMessageTimestamp),
            "lastMessageSenderId": conversation.lastMessageSenderId,
            "unreadCount": [user.id: 0],
            "isTyping": [],
            "deletedBy": [],
            "createdAt": Timestamp(date: conversation.createdAt)
        ]
        try await db.collection("conversations").document(conversation.id).setData(conversationData)
        print("✅ AI pal conversation created: \(conversation.id)")

        // Update user with AI pal conversation ID
        try await db.collection("users").document(user.id).updateData([
            "aiPalConversationId": conversation.id
        ])
        print("✅ User updated with aiPalConversationId")

        await MainActor.run {
            self.authService.currentUser?.aiPalConversationId = conversation.id
        }

        // Send welcome message
        print("📤 Sending welcome message...")
        try await sendWelcomeMessage(conversationId: conversation.id, persona: persona, targetLanguage: targetLanguage)
        print("✅ Welcome message sent!")
    }

    // MARK: - Welcome Message

    private func sendWelcomeMessage(conversationId: String, persona: AIPersona, targetLanguage: String) async throws {
        print("🤖 Generating welcome message for \(targetLanguage)...")

        let welcomePrompt = """
        Generate a friendly welcome message for a new language learner who just signed up. \
        The user is learning \(targetLanguage). \
        Keep it short, warm, and encouraging (2-3 sentences max). \
        Use appropriate emojis and be expressive. \
        Respond ONLY in \(targetLanguage).
        """

        let systemPrompt = persona.systemPromptBase + (authService.currentUser?.aiPersonaCustom ?? "")

        let welcomeMessage = try await callOpenAI(
            messages: [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": welcomePrompt]
            ],
            targetLanguage: targetLanguage
        )

        print("✅ Welcome message generated: \(welcomeMessage)")

        // Create and save the message
        let messageId = UUID().uuidString
        let timestamp = Date()

        let messageData: [String: Any] = [
            "id": messageId,
            "conversationId": conversationId,
            "senderId": AIService.AI_PAL_USER_ID,
            "senderName": authService.currentUser?.aiPalDisplayName ?? "AI Pal",
            "content": welcomeMessage,
            "type": "text",
            "status": "sent",
            "timestamp": Timestamp(date: timestamp),
            "readBy": [],
            "deliveredToUsers": []
        ]

        try await db.collection("conversations").document(conversationId)
            .collection("messages").document(messageId).setData(messageData)

        // Update conversation last message
        try await db.collection("conversations").document(conversationId).updateData([
            "lastMessage": welcomeMessage,
            "lastMessageTimestamp": Timestamp(date: timestamp),
            "lastMessageSenderId": AIService.AI_PAL_USER_ID,
            "unreadCount.\(authService.currentUser?.id ?? "")": FieldValue.increment(Int64(1))
        ])
    }

    // MARK: - AI Response Generation

    func generateAIResponse(userMessage: String, conversationId: String) async throws {
        print("🤖 generateAIResponse called for message: '\(userMessage)'")

        guard let user = authService.currentUser,
              let persona = user.aiPersona,
              let targetLanguage = user.targetLanguage else {
            print("❌ Missing required data for AI response")
            return
        }

        print("✅ Generating AI response in \(targetLanguage)...")

        // Get recent conversation history
        let history = try await getConversationHistory(conversationId: conversationId, limit: 10)

        // Build context
        var messages: [[String: String]] = []

        let systemPrompt = persona.systemPromptBase + (user.aiPersonaCustom ?? "")
        messages.append(["role": "system", "content": systemPrompt])

        let contextPrompt = """
        The user is learning \(targetLanguage). Respond to their messages in \(targetLanguage). \
        Keep responses short and conversational (1-2 sentences) unless explaining an important concept. \
        Use expressive text lingo appropriate to \(targetLanguage) (e.g., "jajaja" for Spanish, "kkkk" for Brazilian Portuguese). \
        Use emojis naturally. Be engaging and supportive.
        """
        messages.append(["role": "system", "content": contextPrompt])

        // Add conversation history
        for msg in history {
            let role = msg.senderId == AIService.AI_PAL_USER_ID ? "assistant" : "user"
            messages.append(["role": role, "content": msg.content])
        }

        // Add current message
        messages.append(["role": "user", "content": userMessage])

        // Generate response
        let aiResponse = try await callOpenAI(messages: messages, targetLanguage: targetLanguage)
        print("✅ AI response generated: \(aiResponse)")

        // Save AI response as message
        let messageId = UUID().uuidString
        let timestamp = Date()

        let messageData: [String: Any] = [
            "id": messageId,
            "conversationId": conversationId,
            "senderId": AIService.AI_PAL_USER_ID,
            "senderName": user.aiPalDisplayName,
            "content": aiResponse,
            "type": "text",
            "status": "sent",
            "timestamp": Timestamp(date: timestamp),
            "readBy": [],
            "deliveredToUsers": []
        ]

        try await db.collection("conversations").document(conversationId)
            .collection("messages").document(messageId).setData(messageData)
        print("✅ AI message saved to Firestore")

        // Update conversation
        try await db.collection("conversations").document(conversationId).updateData([
            "lastMessage": aiResponse,
            "lastMessageTimestamp": Timestamp(date: timestamp),
            "lastMessageSenderId": AIService.AI_PAL_USER_ID,
            "unreadCount.\(user.id)": FieldValue.increment(Int64(1))
        ])
        print("✅ Conversation updated with AI response")
    }

    // MARK: - Scheduled Messages

    func generateScheduledMessage(userId: String, messageType: String) async throws -> String {
        // Fetch user
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let userData = userDoc.data(),
              let targetLanguage = userData["targetLanguage"] as? String,
              let personaType = userData["aiPersonaType"] as? String,
              let conversationId = userData["aiPalConversationId"] as? String,
              let persona = AIPersona(rawValue: personaType) else {
            throw NSError(domain: "AIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid user data"])
        }

        // Get recent history
        let history = try await getConversationHistory(conversationId: conversationId, limit: 5)

        var messages: [[String: String]] = []
        let systemPrompt = persona.systemPromptBase + (userData["aiPersonaCustom"] as? String ?? "")
        messages.append(["role": "system", "content": systemPrompt])

        let prompt: String
        if messageType == "morning" {
            prompt = """
            Generate a friendly conversation starter message for late morning (around 11 AM). \
            Ask how they're doing or share something interesting to practice \(targetLanguage). \
            Keep it short (1-2 sentences). Use emojis. Respond ONLY in \(targetLanguage).
            """
        } else {
            prompt = """
            Generate an evening message (around 7 PM) that teaches something new about \(targetLanguage). \
            Could be a useful phrase, cultural tip, or interesting vocabulary. \
            Keep it engaging and not too formal (2-3 sentences max). Use emojis. Respond ONLY in \(targetLanguage).
            """
        }

        messages.append(["role": "system", "content": "The user is learning \(targetLanguage). Previous conversation context:"])

        // Add recent history
        for msg in history.suffix(3) {
            let role = msg.senderId == AIService.AI_PAL_USER_ID ? "assistant" : "user"
            messages.append(["role": role, "content": msg.content])
        }

        messages.append(["role": "user", "content": prompt])

        let scheduledMessage = try await callOpenAI(messages: messages, targetLanguage: targetLanguage)

        // Save the message
        let message = Message(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: AIService.AI_PAL_USER_ID,
            senderName: userData["displayName"] as? String ?? "AI Pal",
            content: scheduledMessage,
            type: .text,
            status: .sent,
            timestamp: Date()
        )

        let messageDTO = MessageDTO(from: message)
        let messageData = try Firestore.Encoder().encode(messageDTO)
        try await db.collection("conversations").document(conversationId)
            .collection("messages").document(message.id).setData(messageData)

        // Update conversation
        try await db.collection("conversations").document(conversationId).updateData([
            "lastMessage": scheduledMessage,
            "lastMessageTimestamp": Timestamp(date: message.timestamp),
            "lastMessageSenderId": AIService.AI_PAL_USER_ID,
            "unreadCount.\(userId)": FieldValue.increment(Int64(1))
        ])

        return scheduledMessage
    }

    // MARK: - Helper Methods

    private func getConversationHistory(conversationId: String, limit: Int) async throws -> [Message] {
        let snapshot = try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()

        let messages = snapshot.documents.compactMap { doc -> Message? in
            guard let data = try? doc.data(as: MessageDTO.self) else { return nil }
            return data.toMessage()
        }

        return messages.reversed()
    }

    private func callOpenAI(messages: [[String: String]], targetLanguage: String) async throws -> String {
        let data: [String: Any] = [
            "messages": messages,
            "targetLanguage": targetLanguage
        ]

        do {
            let result = try await functions.httpsCallable("generateAIResponse").call(data)

            if let response = result.data as? [String: Any],
               let aiResponse = response["response"] as? String {
                return aiResponse
            } else {
                throw NSError(domain: "AIService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            }
        } catch {
            print("❌ Error calling generateAIResponse: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Suggested Replies

    func generateSuggestedReplies(conversationId: String, recentMessages: [Message]) async throws -> [String] {
        guard let user = authService.currentUser,
              let targetLanguage = user.targetLanguage else {
            return []
        }

        // Build context from recent messages
        var messages: [[String: String]] = []

        let systemPrompt = """
        Generate 1-3 short, natural suggested replies in \(targetLanguage) based on the conversation context, the user's language level, and the user's personality. \
        The replies should be appropriate responses to the last message. \
        Keep each reply very short (3-10 words maximum). \
        Return ONLY a JSON array of strings, like: ["reply1", "reply2", "reply3"]. \
        Use natural, conversational language appropriate for texting. \
        Respond entirely in \(targetLanguage).
        """
        messages.append(["role": "system", "content": systemPrompt])

        // Add recent conversation history
        for msg in recentMessages.suffix(5) {
            let role = msg.senderId == user.id ? "user" : "assistant"
            messages.append(["role": role, "content": msg.content])
        }

        messages.append(["role": "user", "content": "Generate suggested replies as a JSON array."])

        let data: [String: Any] = [
            "messages": messages,
            "targetLanguage": targetLanguage
        ]

        do {
            let result = try await functions.httpsCallable("generateAIResponse").call(data)

            if let response = result.data as? [String: Any],
               let aiResponse = response["response"] as? String {
                // Parse JSON array from response
                if let jsonData = aiResponse.data(using: .utf8),
                   let replies = try? JSONDecoder().decode([String].self, from: jsonData) {
                    return Array(replies.prefix(3))
                }
                // Fallback: try to extract array-like strings
                let cleaned = aiResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.hasPrefix("[") && cleaned.hasSuffix("]") {
                    let inner = cleaned.dropFirst().dropLast()
                    let parts = inner.split(separator: ",").map { part in
                        part.trimmingCharacters(in: .whitespacesAndNewlines)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    }
                    return Array(parts.prefix(3))
                }
            }
            return []
        } catch {
            print("❌ Error generating suggested replies: \(error.localizedDescription)")
            return []
        }
    }
}
