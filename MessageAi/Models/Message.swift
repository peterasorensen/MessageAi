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
    case audio
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
    var readAt: [String: Date] // Dictionary of userId -> timestamp when they read the message
    var deliveredToUsers: [String] // Array of user IDs who have received message locally
    var isOptimistic: Bool // For optimistic UI updates

    // Translation data
    var detectedLanguage: String? // ISO 639-1 language code
    var detectedCountry: String? // Detected country/region (e.g., MX, ES)
    var translatedText: String? // Full message translation
    var sentenceExplanation: String? // Detailed explanation of sentence meaning/context
    var wordTranslationsJSON: String? // JSON-encoded WordTranslation array
    var slangAndIdiomsJSON: String? // JSON-encoded SlangIdiom array
    var isTranslationLoading: Bool // Whether translation is currently being fetched

    // TTS audio cache
    var audioDataBase64: String? // Cached TTS audio for full message (base64-encoded MP3)
    var cachedVoice: String? // Which voice was used for cached audio (for cache invalidation)
    var wordAudioCacheJSON: String? // JSON dictionary mapping words to base64 audio

    // Audio message properties (for MessageType.audio)
    var audioFileURL: String? // Local file path to recorded audio
    var audioDuration: Double? // Duration in seconds
    var audioTranscription: String? // Transcribed text from audio
    var audioTranscriptionLanguage: String? // Detected language of transcription
    var audioTranscriptionJSON: String? // Word translations for transcription text
    var audioWaveformData: String? // JSON-encoded waveform sample array for visualization
    var isTranscriptionReady: Bool // Whether transcription has completed

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
        readAt: [String: Date] = [:],
        deliveredToUsers: [String] = [],
        isOptimistic: Bool = false,
        detectedLanguage: String? = nil,
        detectedCountry: String? = nil,
        translatedText: String? = nil,
        sentenceExplanation: String? = nil,
        wordTranslationsJSON: String? = nil,
        slangAndIdiomsJSON: String? = nil,
        isTranslationLoading: Bool = false,
        audioDataBase64: String? = nil,
        cachedVoice: String? = nil,
        wordAudioCacheJSON: String? = nil,
        audioFileURL: String? = nil,
        audioDuration: Double? = nil,
        audioTranscription: String? = nil,
        audioTranscriptionLanguage: String? = nil,
        audioTranscriptionJSON: String? = nil,
        audioWaveformData: String? = nil,
        isTranscriptionReady: Bool = false
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
        self.readAt = readAt
        self.deliveredToUsers = deliveredToUsers
        self.isOptimistic = isOptimistic
        self.detectedLanguage = detectedLanguage
        self.detectedCountry = detectedCountry
        self.translatedText = translatedText
        self.sentenceExplanation = sentenceExplanation
        self.wordTranslationsJSON = wordTranslationsJSON
        self.slangAndIdiomsJSON = slangAndIdiomsJSON
        self.isTranslationLoading = isTranslationLoading
        self.audioDataBase64 = audioDataBase64
        self.cachedVoice = cachedVoice
        self.wordAudioCacheJSON = wordAudioCacheJSON
        self.audioFileURL = audioFileURL
        self.audioDuration = audioDuration
        self.audioTranscription = audioTranscription
        self.audioTranscriptionLanguage = audioTranscriptionLanguage
        self.audioTranscriptionJSON = audioTranscriptionJSON
        self.audioWaveformData = audioWaveformData
        self.isTranscriptionReady = isTranscriptionReady
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

    var slangAndIdioms: [SlangIdiom] {
        guard let json = slangAndIdiomsJSON,
              let data = json.data(using: .utf8) else {
            return []
        }
        return (try? JSONDecoder().decode([SlangIdiom].self, from: data)) ?? []
    }

    func setSlangAndIdioms(_ items: [SlangIdiom]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(items),
           let json = String(data: data, encoding: .utf8) {
            self.slangAndIdiomsJSON = json
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

    var audioTranscriptionWordTranslations: [WordTranslation] {
        guard let json = audioTranscriptionJSON,
              let data = json.data(using: .utf8) else {
            return []
        }
        return (try? JSONDecoder().decode([WordTranslation].self, from: data)) ?? []
    }

    func setAudioTranscriptionWordTranslations(_ translations: [WordTranslation]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(translations),
           let json = String(data: data, encoding: .utf8) {
            self.audioTranscriptionJSON = json
        }
    }

    var waveformSamples: [Float] {
        guard let json = audioWaveformData,
              let data = json.data(using: .utf8) else {
            return []
        }
        return (try? JSONDecoder().decode([Float].self, from: data)) ?? []
    }

    func setWaveformSamples(_ samples: [Float]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(samples),
           let json = String(data: data, encoding: .utf8) {
            self.audioWaveformData = json
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
    let readAt: [String: Date]
    let deliveredToUsers: [String]
    let detectedLanguage: String?
    let detectedCountry: String?
    let translatedText: String?
    let sentenceExplanation: String?
    let wordTranslationsJSON: String?
    let slangAndIdiomsJSON: String?
    let isTranslationLoading: Bool?
    let audioDuration: Double?
    let audioTranscription: String?
    let audioTranscriptionLanguage: String?
    let audioTranscriptionJSON: String?
    let isTranscriptionReady: Bool?

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
        self.readAt = message.readAt
        self.deliveredToUsers = message.deliveredToUsers
        self.detectedLanguage = message.detectedLanguage
        self.detectedCountry = message.detectedCountry
        self.translatedText = message.translatedText
        self.sentenceExplanation = message.sentenceExplanation
        self.wordTranslationsJSON = message.wordTranslationsJSON
        self.slangAndIdiomsJSON = message.slangAndIdiomsJSON
        self.isTranslationLoading = message.isTranslationLoading
        self.audioDuration = message.audioDuration
        self.audioTranscription = message.audioTranscription
        self.audioTranscriptionLanguage = message.audioTranscriptionLanguage
        self.audioTranscriptionJSON = message.audioTranscriptionJSON
        self.isTranscriptionReady = message.isTranscriptionReady
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
            readAt: readAt,
            deliveredToUsers: deliveredToUsers,
            isOptimistic: false,
            detectedLanguage: detectedLanguage,
            detectedCountry: detectedCountry,
            translatedText: translatedText,
            sentenceExplanation: sentenceExplanation,
            wordTranslationsJSON: wordTranslationsJSON,
            slangAndIdiomsJSON: slangAndIdiomsJSON,
            isTranslationLoading: isTranslationLoading ?? false,
            audioDuration: audioDuration,
            audioTranscription: audioTranscription,
            audioTranscriptionLanguage: audioTranscriptionLanguage,
            audioTranscriptionJSON: audioTranscriptionJSON,
            isTranscriptionReady: isTranscriptionReady ?? false
        )
    }
}
