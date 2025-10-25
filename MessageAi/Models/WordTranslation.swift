//
//  WordTranslation.swift
//  MessageAi
//
//  Created by Apple on 10/24/25.
//

import Foundation

// Matches the structure returned by analyzeMessage Cloud Function
struct WordTranslation: Codable, Identifiable {
    let id: String
    let originalWord: String
    let translation: String
    let partOfSpeech: String
    let startIndex: Int
    let endIndex: Int
    let context: String

    init(originalWord: String, translation: String, partOfSpeech: String, startIndex: Int, endIndex: Int, context: String) {
        self.id = UUID().uuidString
        self.originalWord = originalWord
        self.translation = translation
        self.partOfSpeech = partOfSpeech
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.context = context
    }

    // Custom decoding to add ID if not present
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.originalWord = try container.decode(String.self, forKey: .originalWord)
        self.translation = try container.decode(String.self, forKey: .translation)
        self.partOfSpeech = try container.decode(String.self, forKey: .partOfSpeech)
        self.startIndex = try container.decode(Int.self, forKey: .startIndex)
        self.endIndex = try container.decode(Int.self, forKey: .endIndex)
        self.context = try container.decode(String.self, forKey: .context)
    }

    enum CodingKeys: String, CodingKey {
        case id, originalWord, translation, partOfSpeech, startIndex, endIndex, context
    }
}

// Response structure from analyzeMessage Cloud Function
struct MessageAnalysisResult: Codable {
    let detectedLanguage: String
    let fullTranslation: String
    let wordTranslations: [WordTranslation]
}

// Response structure from expandWordContext Cloud Function
struct WordContextResult: Codable {
    let wordBreakdown: WordBreakdown
    let colloquialMeaning: String
    let multipleMeanings: [MeaningContext]
    let exampleSentences: [ExampleSentence]
}

struct WordBreakdown: Codable {
    let root: String
    let form: String
    let conjugation: String
}

struct MeaningContext: Codable, Identifiable {
    let id: String
    let meaning: String
    let context: String

    init(meaning: String, context: String) {
        self.id = UUID().uuidString
        self.meaning = meaning
        self.context = context
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.meaning = try container.decode(String.self, forKey: .meaning)
        self.context = try container.decode(String.self, forKey: .context)
    }

    enum CodingKeys: String, CodingKey {
        case id, meaning, context
    }
}

struct ExampleSentence: Codable, Identifiable {
    let id: String
    let original: String
    let translation: String

    init(original: String, translation: String) {
        self.id = UUID().uuidString
        self.original = original
        self.translation = translation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.original = try container.decode(String.self, forKey: .original)
        self.translation = try container.decode(String.self, forKey: .translation)
    }

    enum CodingKeys: String, CodingKey {
        case id, original, translation
    }
}
