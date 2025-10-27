//
//  User.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: String
    var displayName: String
    var email: String
    var phoneNumber: String?
    var avatarURL: String?
    var isOnline: Bool
    var lastSeen: Date
    var createdAt: Date
    var fcmToken: String? // Firebase Cloud Messaging token for push notifications

    // Translation preferences
    var targetLanguage: String? // Language user is learning (e.g., "es", "fr")
    var fluentLanguage: String? // Language user is fluent in (e.g., "en")
    var autoTranslateEnabled: Bool // Auto-translate all incoming messages
    var needsOnboarding: Bool // Show onboarding flow on first launch

    // AI Pal preferences
    var aiPersonaType: String? // AI personality type: bro, sis, boyfriend, girlfriend, teacher, ai, custom
    var aiPersonaCustom: String? // Custom persona description (max 200 chars) if type is "custom"
    var aiPalConversationId: String? // Conversation ID for the AI pal chat

    // TTS preferences
    var preferredTTSVoice: String? // User's preferred TTS voice (alloy, ash, ballad, coral, echo, fable, onyx, nova, sage, shimmer, verse)

    init(
        id: String,
        displayName: String,
        email: String,
        phoneNumber: String? = nil,
        avatarURL: String? = nil,
        isOnline: Bool = false,
        lastSeen: Date = Date(),
        createdAt: Date = Date(),
        fcmToken: String? = nil,
        targetLanguage: String? = nil,
        fluentLanguage: String? = nil,
        autoTranslateEnabled: Bool = false,
        needsOnboarding: Bool = true,
        aiPersonaType: String? = nil,
        aiPersonaCustom: String? = nil,
        aiPalConversationId: String? = nil,
        preferredTTSVoice: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.phoneNumber = phoneNumber
        self.avatarURL = avatarURL
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.createdAt = createdAt
        self.fcmToken = fcmToken
        self.targetLanguage = targetLanguage
        self.fluentLanguage = fluentLanguage
        self.autoTranslateEnabled = autoTranslateEnabled
        self.needsOnboarding = needsOnboarding
        self.aiPersonaType = aiPersonaType
        self.aiPersonaCustom = aiPersonaCustom
        self.aiPalConversationId = aiPalConversationId
        self.preferredTTSVoice = preferredTTSVoice
    }
}

// Firestore DTO for sync
struct UserDTO: Codable {
    let id: String
    let displayName: String
    let email: String
    let phoneNumber: String?
    let avatarURL: String?
    let isOnline: Bool
    let lastSeen: Date
    let createdAt: Date
    let fcmToken: String?
    let targetLanguage: String?
    let fluentLanguage: String?
    let autoTranslateEnabled: Bool
    let needsOnboarding: Bool
    let aiPersonaType: String?
    let aiPersonaCustom: String?
    let aiPalConversationId: String?
    let preferredTTSVoice: String?

    init(from user: User) {
        self.id = user.id
        self.displayName = user.displayName
        self.email = user.email
        self.phoneNumber = user.phoneNumber
        self.avatarURL = user.avatarURL
        self.isOnline = user.isOnline
        self.lastSeen = user.lastSeen
        self.createdAt = user.createdAt
        self.fcmToken = user.fcmToken
        self.targetLanguage = user.targetLanguage
        self.fluentLanguage = user.fluentLanguage
        self.autoTranslateEnabled = user.autoTranslateEnabled
        self.needsOnboarding = user.needsOnboarding
        self.aiPersonaType = user.aiPersonaType
        self.aiPersonaCustom = user.aiPersonaCustom
        self.aiPalConversationId = user.aiPalConversationId
        self.preferredTTSVoice = user.preferredTTSVoice
    }

    func toUser() -> User {
        return User(
            id: id,
            displayName: displayName,
            email: email,
            phoneNumber: phoneNumber,
            avatarURL: avatarURL,
            isOnline: isOnline,
            lastSeen: lastSeen,
            createdAt: createdAt,
            fcmToken: fcmToken,
            targetLanguage: targetLanguage,
            fluentLanguage: fluentLanguage,
            autoTranslateEnabled: autoTranslateEnabled,
            needsOnboarding: needsOnboarding,
            aiPersonaType: aiPersonaType,
            aiPersonaCustom: aiPersonaCustom,
            aiPalConversationId: aiPalConversationId,
            preferredTTSVoice: preferredTTSVoice
        )
    }
}
