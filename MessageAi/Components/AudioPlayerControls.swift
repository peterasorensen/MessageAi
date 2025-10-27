//
//  AudioPlayerControls.swift
//  MessageAi
//
//  Audio playback controls with waveform visualization
//

import SwiftUI
import AVFoundation
import Observation

@Observable
@MainActor
final class AudioPlayerState: NSObject, AVAudioPlayerDelegate {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var progress: Double = 0

    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?

    func loadAudio(url: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        duration = audioPlayer?.duration ?? 0
    }

    func play() {
        guard let player = audioPlayer else { return }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default)
        try? audioSession.setActive(true)

        player.play()
        isPlaying = true
        startProgressTimer()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopProgressTimer()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to position: Double) {
        guard let player = audioPlayer else { return }
        let time = position * duration
        player.currentTime = time
        currentTime = time
        progress = position
    }

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
        progress = duration > 0 ? currentTime / duration : 0
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            stopProgressTimer()
            currentTime = 0
            progress = 0
            try? AVAudioSession.sharedInstance().setActive(false)
        }
    }

    func cleanup() {
        pause()
        audioPlayer = nil
    }
}

struct AudioPlayerControls: View {
    let audioURL: URL
    let waveformSamples: [Float]
    let duration: TimeInterval

    @State private var playerState = AudioPlayerState()

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Play/Pause button
                Button(action: {
                    playerState.togglePlayPause()
                }) {
                    Image(systemName: playerState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.blue)
                }

                // Waveform with progress
                PlaybackWaveformView(
                    samples: waveformSamples,
                    progress: playerState.progress,
                    onSeek: { position in
                        playerState.seek(to: position)
                    }
                )

                // Duration label
                Text(formatTime(playerState.isPlaying ? playerState.currentTime : duration))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
            }
        }
        .onAppear {
            try? playerState.loadAudio(url: audioURL)
        }
        .onDisappear {
            playerState.cleanup()
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    AudioPlayerControls(
        audioURL: URL(fileURLWithPath: "/tmp/test.m4a"),
        waveformSamples: (0..<50).map { _ in Float.random(in: 0.2...1.0) },
        duration: 125.0
    )
    .padding()
}
