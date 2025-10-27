//
//  AudioRecorderService.swift
//  MessageAi
//
//  Audio recording service with waveform generation
//

import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
final class AudioRecorderService: NSObject {
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var waveformSamples: [Float] = []
    var currentRecordingURL: URL?

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var meteringTimer: Timer?
    private let maxWaveformSamples = 100

    override init() {
        super.init()
    }

    func startRecording() async throws -> URL {
        // Request microphone permission
        let permissionGranted = await requestMicrophonePermission()
        guard permissionGranted else {
            throw AudioRecorderError.permissionDenied
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)

        // Create unique file URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(UUID().uuidString).m4a")

        // Audio recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Initialize recorder
        audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.delegate = self

        guard let recorder = audioRecorder else {
            throw AudioRecorderError.initializationFailed
        }

        // Start recording
        guard recorder.record() else {
            throw AudioRecorderError.recordingFailed
        }

        isRecording = true
        recordingDuration = 0
        waveformSamples = []
        currentRecordingURL = audioFilename

        // Start timers for duration and metering
        startTimers()

        return audioFilename
    }

    func stopRecording() -> (url: URL, duration: TimeInterval, waveform: [Float])? {
        guard let recorder = audioRecorder, isRecording else { return nil }

        recorder.stop()
        stopTimers()

        let finalURL = recorder.url
        let finalDuration = recordingDuration
        let finalWaveform = waveformSamples

        isRecording = false

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)

        return (finalURL, finalDuration, finalWaveform)
    }

    func cancelRecording() {
        guard let recorder = audioRecorder, isRecording else { return }

        let recordingURL = recorder.url
        recorder.stop()
        stopTimers()

        // Delete the recording file
        try? FileManager.default.removeItem(at: recordingURL)

        isRecording = false
        recordingDuration = 0
        waveformSamples = []
        currentRecordingURL = nil

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func startTimers() {
        // Timer for recording duration
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 0.1
            }
        }

        // Timer for audio metering (waveform)
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateWaveform()
            }
        }
    }

    private func stopTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        meteringTimer?.invalidate()
        meteringTimer = nil
    }

    private func updateWaveform() {
        guard let recorder = audioRecorder else { return }

        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)

        // Convert dB to normalized amplitude (0.0 to 1.0)
        // -160 dB is silence, 0 dB is max
        let normalizedPower = max(0.0, min(1.0, (power + 160.0) / 160.0))

        // Add to waveform samples
        waveformSamples.append(normalizedPower)

        // Keep only the most recent samples for visualization
        if waveformSamples.count > maxWaveformSamples {
            waveformSamples.removeFirst()
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                print("Recording failed")
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("Recording encode error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Errors
enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case initializationFailed
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied"
        case .initializationFailed:
            return "Failed to initialize audio recorder"
        case .recordingFailed:
            return "Failed to start recording"
        }
    }
}
