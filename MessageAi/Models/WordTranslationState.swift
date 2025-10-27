//
//  WordTranslationState.swift
//  MessageAi
//
//  Created by Apple on 10/24/25.
//

import SwiftUI

@Observable
class WordTranslationState {
    var selectedWordTranslation: WordTranslation?
    var wordPosition: CGRect = .zero
    var showDetailedView: Bool = false
    var selectedTargetLanguage: String?
    var selectedFluentLanguage: String?
    var selectedMessage: Message? // For TTS audio caching

    func selectWord(_ translation: WordTranslation, at position: CGRect, targetLanguage: String?, fluentLanguage: String?, message: Message? = nil) {
        self.selectedWordTranslation = translation
        self.wordPosition = position
        self.selectedTargetLanguage = targetLanguage
        self.selectedFluentLanguage = fluentLanguage
        self.selectedMessage = message
    }

    func dismissWord() {
        self.selectedWordTranslation = nil
        self.showDetailedView = false
        self.selectedMessage = nil
    }
}
