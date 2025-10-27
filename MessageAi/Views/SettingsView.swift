//
//  SettingsView.swift
//  MessageAi
//
//  Created by Apple on 10/24/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @Environment(TranslationService.self) private var translationService
    @Environment(TTSService.self) private var ttsService
    @Environment(\.dismiss) private var dismiss

    @State private var showLanguageOnboarding = false
    @State private var autoTranslateEnabled = false
    @State private var showClearCacheAlert = false
    @State private var selectedVoice: String = "nova"
    @State private var isPlayingPreview = false

    let languages: [Language] = [
        Language(code: "en", name: "English", flag: "🇺🇸"),
        Language(code: "es", name: "Spanish", flag: "🇪🇸"),
        Language(code: "fr", name: "French", flag: "🇫🇷"),
        Language(code: "de", name: "German", flag: "🇩🇪"),
        Language(code: "it", name: "Italian", flag: "🇮🇹"),
        Language(code: "pt", name: "Portuguese", flag: "🇵🇹"),
        Language(code: "ru", name: "Russian", flag: "🇷🇺"),
        Language(code: "zh", name: "Chinese", flag: "🇨🇳"),
        Language(code: "ja", name: "Japanese", flag: "🇯🇵"),
        Language(code: "ko", name: "Korean", flag: "🇰🇷"),
        Language(code: "ar", name: "Arabic", flag: "🇸🇦"),
        Language(code: "hi", name: "Hindi", flag: "🇮🇳"),
    ]

    let voices: [(id: String, name: String, description: String)] = [
        ("alloy", "Alloy", "Neutral, balanced"),
        ("ash", "Ash", "Clear, articulate"),
        ("ballad", "Ballad", "Warm, expressive"),
        ("coral", "Coral", "Feminine, warm"),
        ("echo", "Echo", "Masculine, friendly"),
        ("fable", "Fable", "Masculine, warm"),
        ("onyx", "Onyx", "Deep, authoritative"),
        ("nova", "Nova", "Feminine, bright"),
        ("sage", "Sage", "Neutral, wise"),
        ("shimmer", "Shimmer", "Feminine, gentle"),
        ("verse", "Verse", "Clear, expressive")
    ]

    var body: some View {
        NavigationStack {
            List {
                // Translation Section
                Section {
                    HStack {
                        Text("Target Language")
                        Spacer()
                        Text(languageName(for: authService.currentUser?.targetLanguage))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Fluent Language")
                        Spacer()
                        Text(languageName(for: authService.currentUser?.fluentLanguage))
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Auto-Translate Messages", isOn: Binding(
                        get: { authService.currentUser?.autoTranslateEnabled ?? false },
                        set: { newValue in
                            Task {
                                await updateAutoTranslate(newValue)
                            }
                        }
                    ))

                    Button {
                        showLanguageOnboarding = true
                    } label: {
                        HStack {
                            Text("Change Language Settings")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Translation")
                } footer: {
                    Text("Auto-translate automatically translates incoming messages from any language into your target language.")
                }

                // TTS Voice Section
                Section {
                    Picker("Voice", selection: Binding(
                        get: { authService.currentUser?.preferredTTSVoice ?? "nova" },
                        set: { newValue in
                            selectedVoice = newValue
                            Task {
                                await updateTTSVoice(newValue)
                            }
                        }
                    )) {
                        ForEach(voices, id: \.id) { voice in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(voice.name)
                                    .font(.body)
                                Text(voice.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(voice.id)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Button {
                        playVoicePreview()
                    } label: {
                        HStack {
                            Image(systemName: isPlayingPreview ? "stop.circle.fill" : "play.circle.fill")
                            Text(isPlayingPreview ? "Stop Preview" : "Preview Voice")
                        }
                    }
                    .disabled(authService.currentUser?.targetLanguage == nil)
                } header: {
                    Text("Text-to-Speech Voice")
                } footer: {
                    Text("Choose your preferred voice for message pronunciation. Voice will automatically match AI persona in AI Pal conversations.")
                }

                // Cache Section
                Section {
                    Button(role: .destructive) {
                        showClearCacheAlert = true
                    } label: {
                        Text("Clear Translation Cache")
                    }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Clears cached translations. This will not affect your messages, but may require re-fetching translations.")
                }

                // Account Section
                Section {
                    HStack {
                        Text("Display Name")
                        Spacer()
                        Text(authService.currentUser?.displayName ?? "")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Email")
                        Spacer()
                        Text(authService.currentUser?.email ?? "")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Account")
                }

                // Sign Out
                Section {
                    Button(role: .destructive) {
                        Task {
                            try? await authService.signOut()
                        }
                    } label: {
                        Text("Sign Out")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showLanguageOnboarding) {
                LanguageOnboardingView()
            }
            .alert("Clear Cache", isPresented: $showClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    translationService.clearCache()
                }
            } message: {
                Text("Are you sure you want to clear all cached translations?")
            }
        }
    }

    // MARK: - Helpers

    private func languageName(for code: String?) -> String {
        guard let code = code,
              let language = languages.first(where: { $0.code == code }) else {
            return "Not set"
        }
        return "\(language.flag) \(language.name)"
    }

    private func updateAutoTranslate(_ enabled: Bool) async {
        guard let user = authService.currentUser else { return }
        user.autoTranslateEnabled = enabled
        try? await authService.updateUserProfile(autoTranslateEnabled: enabled)
    }

    private func updateTTSVoice(_ voice: String) async {
        guard let user = authService.currentUser else { return }
        user.preferredTTSVoice = voice
        // Update in Firestore
        let db = Firestore.firestore()
        try? await db.collection("users").document(user.id).updateData([
            "preferredTTSVoice": voice
        ])
    }

    private func playVoicePreview() {
        guard let targetLanguage = authService.currentUser?.targetLanguage else { return }

        // Stop if currently playing
        if ttsService.isPlaying {
            ttsService.stopAudio()
            isPlayingPreview = false
            return
        }

        // Get sample text based on target language
        let sampleTexts: [String: String] = [
            "es": "Hola, este es un ejemplo de mi voz.",
            "fr": "Bonjour, ceci est un exemple de ma voix.",
            "de": "Hallo, das ist ein Beispiel meiner Stimme.",
            "it": "Ciao, questo è un esempio della mia voce.",
            "pt": "Olá, este é um exemplo da minha voz.",
            "ru": "Привет, это пример моего голоса.",
            "zh": "你好，这是我的声音示例。",
            "ja": "こんにちは、これは私の声のサンプルです。",
            "ko": "안녕하세요, 이것은 제 목소리의 샘플입니다.",
            "ar": "مرحبا، هذا مثال على صوتي.",
            "hi": "नमस्ते, यह मेरी आवाज़ का एक उदाहरण है।",
            "en": "Hello, this is an example of my voice."
        ]

        let sampleText = sampleTexts[targetLanguage] ?? "Hello, this is an example of my voice."
        let voice = authService.currentUser?.preferredTTSVoice ?? "nova"

        isPlayingPreview = true

        Task {
            do {
                // Generate TTS directly without caching
                let functions = Functions.functions()
                let generateTTS = functions.httpsCallable("generateTTS")

                let data: [String: Any] = [
                    "text": sampleText,
                    "language": targetLanguage,
                    "voice": voice
                ]

                let result = try await generateTTS.call(data)
                guard let resultData = result.data as? [String: Any],
                      let audioData = resultData["audioData"] as? String else {
                    print("❌ Invalid TTS response")
                    isPlayingPreview = false
                    return
                }

                // Play the audio using a temporary message
                let tempMessage = Message(
                    conversationId: "preview",
                    senderId: "preview",
                    senderName: "Preview",
                    content: sampleText
                )
                tempMessage.audioDataBase64 = audioData
                tempMessage.cachedVoice = voice

                try await ttsService.playMessageAudio(
                    message: tempMessage,
                    text: sampleText,
                    language: targetLanguage,
                    voice: voice
                )

                // Monitor playback state
                Task {
                    while ttsService.isPlaying {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    }
                    isPlayingPreview = false
                }
            } catch {
                print("❌ Failed to play preview: \(error)")
                isPlayingPreview = false
            }
        }
    }
}

// Helper imports
import FirebaseFunctions

// Helper to import Firestore
import FirebaseFirestore
