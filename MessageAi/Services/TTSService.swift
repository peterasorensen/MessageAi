//
//  TTSService.swift
//  MessageAi
//
//  Text-to-Speech service using OpenAI gpt-4o-mini-tts model
//  Handles audio generation, caching, and playback
//

import Foundation
import AVFoundation
import Firebase
import FirebaseFunctions

@Observable
@MainActor
class TTSService: NSObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?

    var isPlaying: Bool = false
    var playingMessageId: String?
    var playingWord: String?

    override init() {
        super.init()
        // Configure audio session for playback
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Voice Selection

    /// Determines the appropriate voice for a message sender
    /// - AI Pal: Matches persona (bro→onyx, sis→nova, etc)
    /// - Regular users: Uses user's preferred voice setting
    func getVoiceForSender(senderId: String, aiPersonaType: String?, userPreference: String?) -> String {
        // Check if sender is AI Pal
        if senderId == "ai-pal-system", let persona = aiPersonaType {
            return getVoiceForAIPersona(persona)
        }

        // Use user's preferred voice, or default to "nova"
        return userPreference ?? "nova"
    }

    private func getVoiceForAIPersona(_ personaType: String) -> String {
        let personaVoices: [String: String] = [
            "bro": "onyx",           // Masculine, friendly
            "sis": "nova",            // Feminine, warm
            "boyfriend": "fable",     // Masculine, warm
            "girlfriend": "coral",    // Feminine, warm
            "teacher": "sage",        // Neutral, authoritative
            "ai": "alloy",           // Neutral, balanced
            "custom": "alloy"         // Default neutral
        ]

        return personaVoices[personaType] ?? "nova"
    }

    // MARK: - Message Audio

    /// Plays TTS audio for a full message
    /// Uses cached audio if available, otherwise generates new audio
    func playMessageAudio(message: Message, text: String, language: String, voice: String) async throws {
        // Stop any currently playing audio
        stopAudio()

        print("🎤 playMessageAudio called - text: \(text.prefix(50))..., language: \(language), voice: \(voice)")

        // Check cache - validate voice matches
        if let cachedAudio = message.audioDataBase64,
           let cachedVoice = message.cachedVoice,
           cachedVoice == voice,
           !cachedAudio.isEmpty {
            print("🎵 Playing cached audio for message: \(message.id)")
            try playAudioFromBase64(cachedAudio, messageId: message.id)
            return
        }

        // Generate new audio
        print("🎤 Generating TTS audio for message: \(message.id)")
        let audioData = try await generateTTS(text: text, language: language, voice: voice)

        print("✅ Got audio data: \(audioData.prefix(50))...")

        // Cache the audio
        message.audioDataBase64 = audioData
        message.cachedVoice = voice

        // Play the audio
        try playAudioFromBase64(audioData, messageId: message.id)
    }

    // MARK: - Word Audio

    /// Plays TTS audio for a single word
    /// Caches word audio in message for faster subsequent playback
    func playWordAudio(word: String, language: String, voice: String, message: Message? = nil) async throws {
        // Stop any currently playing audio
        stopAudio()

        print("🎤 playWordAudio called - word: \(word), language: \(language), voice: \(voice)")

        // Check word cache if message provided
        if let message = message {
            let cache = message.wordAudioCache
            if let cachedAudio = cache[word], !cachedAudio.isEmpty {
                print("🎵 Playing cached word audio: \(word)")
                try playAudioFromBase64(cachedAudio, word: word)
                return
            }
        }

        // Generate new audio for word
        print("🎤 Generating TTS audio for word: \(word)")
        let audioData = try await generateTTS(text: word, language: language, voice: voice)

        print("✅ Got audio data for word: \(word)")

        // Cache the word audio if message provided
        if let message = message {
            var cache = message.wordAudioCache
            cache[word] = audioData
            message.setWordAudioCache(cache)
        }

        // Play the audio
        try playAudioFromBase64(audioData, word: word)
    }

    // MARK: - TTS Generation

    private func generateTTS(text: String, language: String, voice: String) async throws -> String {
        let functions = Functions.functions()
        let generateTTS = functions.httpsCallable("generateTTS")

        let data: [String: Any] = [
            "text": text,
            "language": language,
            "voice": voice
        ]

        do {
            let result = try await generateTTS.call(data)
            guard let resultData = result.data as? [String: Any],
                  let audioData = resultData["audioData"] as? String else {
                throw TTSError.invalidResponse
            }

            return audioData
        } catch {
            print("❌ Failed to generate TTS: \(error)")
            throw TTSError.generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Audio Playback

    private func playAudioFromBase64(_ base64Audio: String, messageId: String? = nil, word: String? = nil) throws {
        guard let audioData = Data(base64Encoded: base64Audio) else {
            throw TTSError.invalidAudioData
        }

        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self

            audioPlayer?.prepareToPlay()
            audioPlayer?.play()

            isPlaying = true
            playingMessageId = messageId
            playingWord = word

            print("🔊 Playing audio (messageId: \(messageId ?? "nil"), word: \(word ?? "nil"))...")
        } catch {
            print("❌ Failed to play audio: \(error)")
            throw TTSError.playbackFailed(error.localizedDescription)
        }
    }

    /// Stops currently playing audio
    func stopAudio() {
        print("🛑 Stopping audio playback")
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playingMessageId = nil
        playingWord = nil
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            print("✅ Audio playback finished (success: \(flag))")
            self.isPlaying = false
            self.playingMessageId = nil
            self.playingWord = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("❌ Audio decode error: \(error?.localizedDescription ?? "unknown")")
            self.isPlaying = false
            self.playingMessageId = nil
            self.playingWord = nil
        }
    }
}

// MARK: - Errors

enum TTSError: LocalizedError {
    case invalidResponse
    case generationFailed(String)
    case invalidAudioData
    case playbackFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from TTS service"
        case .generationFailed(let message):
            return "Failed to generate audio: \(message)"
        case .invalidAudioData:
            return "Invalid audio data received"
        case .playbackFailed(let message):
            return "Failed to play audio: \(message)"
        }
    }
}
