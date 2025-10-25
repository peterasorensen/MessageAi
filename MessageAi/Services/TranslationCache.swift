//
//  TranslationCache.swift
//  MessageAi
//
//  Created by Apple on 10/24/25.
//

import Foundation

@Observable
class TranslationCache {
    private let userDefaults = UserDefaults.standard
    private let cachePrefix = "translation_cache_"
    private let wordContextPrefix = "word_context_cache_"
    private let cacheDuration: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    struct CacheEntry: Codable {
        let result: Data
        let timestamp: Date
    }

    // MARK: - Message Analysis Cache

    func cacheMessageAnalysis(messageText: String, result: MessageAnalysisResult) {
        let key = cacheKey(for: messageText)
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(result) {
            let entry = CacheEntry(result: data, timestamp: Date())
            if let entryData = try? encoder.encode(entry) {
                userDefaults.set(entryData, forKey: key)
            }
        }
    }

    func getCachedMessageAnalysis(messageText: String) -> MessageAnalysisResult? {
        let key = cacheKey(for: messageText)
        guard let entryData = userDefaults.data(forKey: key),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: entryData) else {
            return nil
        }

        // Check if cache is expired
        if Date().timeIntervalSince(entry.timestamp) > cacheDuration {
            userDefaults.removeObject(forKey: key)
            return nil
        }

        return try? JSONDecoder().decode(MessageAnalysisResult.self, from: entry.result)
    }

    // MARK: - Word Context Cache

    func cacheWordContext(word: String, sourceLanguage: String, result: WordContextResult) {
        let key = wordContextKey(for: word, language: sourceLanguage)
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(result) {
            let entry = CacheEntry(result: data, timestamp: Date())
            if let entryData = try? encoder.encode(entry) {
                userDefaults.set(entryData, forKey: key)
            }
        }
    }

    func getCachedWordContext(word: String, sourceLanguage: String) -> WordContextResult? {
        let key = wordContextKey(for: word, language: sourceLanguage)
        guard let entryData = userDefaults.data(forKey: key),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: entryData) else {
            return nil
        }

        // Check if cache is expired
        if Date().timeIntervalSince(entry.timestamp) > cacheDuration {
            userDefaults.removeObject(forKey: key)
            return nil
        }

        return try? JSONDecoder().decode(WordContextResult.self, from: entry.result)
    }

    // MARK: - Cache Management

    func clearAllCache() {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix(cachePrefix) || key.hasPrefix(wordContextPrefix) {
                userDefaults.removeObject(forKey: key)
            }
        }
    }

    func clearExpiredCache() {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix(cachePrefix) || key.hasPrefix(wordContextPrefix) {
            if let entryData = userDefaults.data(forKey: key),
               let entry = try? JSONDecoder().decode(CacheEntry.self, from: entryData),
               Date().timeIntervalSince(entry.timestamp) > cacheDuration {
                userDefaults.removeObject(forKey: key)
            }
        }
    }

    // MARK: - Private Helpers

    private func cacheKey(for text: String) -> String {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(cachePrefix)\(normalized.hash)"
    }

    private func wordContextKey(for word: String, language: String) -> String {
        let normalized = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(wordContextPrefix)\(language)_\(normalized.hash)"
    }
}
