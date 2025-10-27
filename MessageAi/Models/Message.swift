//
//  Message.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import Foundation
import SwiftData

enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

enum MessageType: String, Codable {
    case text
    case image
    case system
}

@Model
final class Message {
    @Attribute(.unique) var id: String
    var conversationId: String
    var senderId: String
    var senderName: String
    var content: String
    var type: String // MessageType raw value
    var status: String // MessageStatus raw value
    var timestamp: Date
    var readBy: [String] // Array of user IDs who have read this message
    var deliveredToUsers: [String] // Array of user IDs who have received message locally
    var isOptimistic: Bool // For optimistic UI updates

    // Translation data
    var detectedLanguage: String? // ISO 639-1 language code
    var translatedText: String? // Full message translation
    var wordTranslationsJSON: String? // JSON-encoded WordTranslation array

    // TTS audio cache
    var audioDataBase64: String? // Cached TTS audio for full message (base64-encoded MP3)
    var cachedVoice: String? // Which voice was used for cached audio (for cache invalidation)
    var wordAudioCacheJSON: String? // JSON dictionary mapping words to base64 audio

    init(
        id: String = UUID().uuidString,
        conversationId: String,
        senderId: String,
        senderName: String,
        content: String,
        type: MessageType = .text,
        status: MessageStatus = .sending,
        timestamp: Date = Date(),
        readBy: [String] = [],
        deliveredToUsers: [String] = [],
        isOptimistic: Bool = false,
        detectedLanguage: String? = nil,
        translatedText: String? = nil,
        wordTranslationsJSON: String? = nil,
        audioDataBase64: String? = nil,
        cachedVoice: String? = nil,
        wordAudioCacheJSON: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.content = content
        self.type = type.rawValue
        self.status = status.rawValue
        self.timestamp = timestamp
        self.readBy = readBy
        self.deliveredToUsers = deliveredToUsers
        self.isOptimistic = isOptimistic
        self.detectedLanguage = detectedLanguage
        self.translatedText = translatedText
        self.wordTranslationsJSON = wordTranslationsJSON
        self.audioDataBase64 = audioDataBase64
        self.cachedVoice = cachedVoice
        self.wordAudioCacheJSON = wordAudioCacheJSON
    }

    var messageType: MessageType {
        MessageType(rawValue: type) ?? .text
    }

    var messageStatus: MessageStatus {
        MessageStatus(rawValue: status) ?? .sent
    }

    var wordTranslations: [WordTranslation] {
        guard let json = wordTranslationsJSON,
              let data = json.data(using: .utf8) else {
            return []
        }
        return (try? JSONDecoder().decode([WordTranslation].self, from: data)) ?? []
    }

    func setWordTranslations(_ translations: [WordTranslation]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(translations),
           let json = String(data: data, encoding: .utf8) {
            self.wordTranslationsJSON = json
        }
    }

    var wordAudioCache: [String: String] {
        guard let json = wordAudioCacheJSON,
              let data = json.data(using: .utf8) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    func setWordAudioCache(_ cache: [String: String]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(cache),
           let json = String(data: data, encoding: .utf8) {
            self.wordAudioCacheJSON = json
        }
    }
}

// Firestore DTO for sync
struct MessageDTO: Codable {
    let id: String
    let conversationId: String
    let senderId: String
    let senderName: String
    let content: String
    let type: String
    let status: String
    let timestamp: Date
    let readBy: [String]
    let deliveredToUsers: [String]
    let detectedLanguage: String?
    let translatedText: String?
    let wordTranslationsJSON: String?

    init(from message: Message) {
        self.id = message.id
        self.conversationId = message.conversationId
        self.senderId = message.senderId
        self.senderName = message.senderName
        self.content = message.content
        self.type = message.type
        self.status = message.status
        self.timestamp = message.timestamp
        self.readBy = message.readBy
        self.deliveredToUsers = message.deliveredToUsers
        self.detectedLanguage = message.detectedLanguage
        self.translatedText = message.translatedText
        self.wordTranslationsJSON = message.wordTranslationsJSON
    }

    func toMessage() -> Message {
        return Message(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            content: content,
            type: MessageType(rawValue: type) ?? .text,
            status: MessageStatus(rawValue: status) ?? .sent,
            timestamp: timestamp,
            readBy: readBy,
            deliveredToUsers: deliveredToUsers,
            isOptimistic: false,
            detectedLanguage: detectedLanguage,
            translatedText: translatedText,
            wordTranslationsJSON: wordTranslationsJSON
        )
    }
}
