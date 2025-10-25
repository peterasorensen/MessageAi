//
//  TranslationService.swift
//  MessageAi
//
//  Created by Apple on 10/24/25.
//

import Foundation
import FirebaseFunctions

@Observable
class TranslationService {
    private let functions = Functions.functions()
    private let cache = TranslationCache()

    var isLoading = false
    var error: String?

    // MARK: - Analyze Message

    /// Analyzes a message: detects language, translates full text, and provides word-by-word translations
    func analyzeMessage(
        messageText: String,
        targetLanguage: String,
        fluentLanguage: String
    ) async throws -> MessageAnalysisResult {
        // Check cache first
        if let cached = cache.getCachedMessageAnalysis(messageText: messageText) {
            print("📦 Using cached translation for: \(messageText.prefix(30))...")
            return cached
        }

        await MainActor.run { isLoading = true }

        do {
            let data: [String: Any] = [
                "messageText": messageText,
                "targetLanguage": targetLanguage,
                "fluentLanguage": fluentLanguage
            ]

            let result = try await functions.httpsCallable("analyzeMessage").call(data)

            guard let responseData = result.data as? [String: Any] else {
                throw TranslationError.invalidResponse
            }

            // Convert to JSON data for decoding
            let jsonData = try JSONSerialization.data(withJSONObject: responseData)
            let analysisResult = try JSONDecoder().decode(MessageAnalysisResult.self, from: jsonData)

            // Cache the result
            cache.cacheMessageAnalysis(messageText: messageText, result: analysisResult)

            print("✅ Analyzed message in \(analysisResult.detectedLanguage) with \(analysisResult.wordTranslations.count) word translations")

            await MainActor.run {
                isLoading = false
                error = nil
            }

            return analysisResult

        } catch {
            await MainActor.run {
                isLoading = false
                self.error = error.localizedDescription
            }
            throw error
        }
    }

    // MARK: - Expand Word Context

    /// Gets detailed context for a specific word: etymology, meanings, examples
    func expandWordContext(
        word: String,
        sourceLanguage: String,
        targetLanguage: String
    ) async throws -> WordContextResult {
        // Check cache first
        if let cached = cache.getCachedWordContext(word: word, sourceLanguage: sourceLanguage) {
            print("📦 Using cached word context for: \(word)")
            return cached
        }

        await MainActor.run { isLoading = true }

        do {
            let data: [String: Any] = [
                "word": word,
                "sourceLanguage": sourceLanguage,
                "targetLanguage": targetLanguage
            ]

            let result = try await functions.httpsCallable("expandWordContext").call(data)

            guard let responseData = result.data as? [String: Any] else {
                throw TranslationError.invalidResponse
            }

            // Convert to JSON data for decoding
            let jsonData = try JSONSerialization.data(withJSONObject: responseData)
            let contextResult = try JSONDecoder().decode(WordContextResult.self, from: jsonData)

            // Cache the result
            cache.cacheWordContext(word: word, sourceLanguage: sourceLanguage, result: contextResult)

            print("✅ Expanded context for word: \(word)")

            await MainActor.run {
                isLoading = false
                error = nil
            }

            return contextResult

        } catch {
            await MainActor.run {
                isLoading = false
                self.error = error.localizedDescription
            }
            throw error
        }
    }

    // MARK: - Cache Management

    func clearCache() {
        cache.clearAllCache()
    }

    func clearExpiredCache() {
        cache.clearExpiredCache()
    }
}

enum TranslationError: LocalizedError {
    case invalidResponse
    case missingLanguagePreferences
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from translation service"
        case .missingLanguagePreferences:
            return "Please set your language preferences in settings"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
