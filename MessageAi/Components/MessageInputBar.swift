//
//  MessageInputBar.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import SwiftUI

struct MessageInputBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let onSend: () -> Void
    let onAudioSend: (URL, Double, [Float]) -> Void
    let onTypingChanged: (Bool) -> Void
    let suggestedReplies: [String]
    let onSuggestedReplyTap: (String) -> Void

    @State private var typingTimer: Timer?
    @State private var audioRecorder = AudioRecorderService()
    @State private var showRecordingUI = false
    @State private var showSuggestedReplies = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            if showRecordingUI {
                // Recording UI
                recordingView
            } else {
                // Suggested replies
                SuggestedRepliesView(
                    suggestions: suggestedReplies,
                    onSelect: handleSuggestedReply,
                    isExpanded: showSuggestedReplies
                )

                // Normal input UI
                HStack(alignment: .bottom, spacing: 12) {
                    // Suggested replies button
                    if !suggestedReplies.isEmpty {
                        Button(action: toggleSuggestedReplies) {
                            Image(systemName: showSuggestedReplies ? "lightbulb.fill" : "lightbulb")
                                .font(.system(size: 24))
                                .foregroundStyle(.blue)
                                .frame(width: 32, height: 32)
                        }
                        .animation(.easeInOut(duration: 0.2), value: showSuggestedReplies)
                    }

                    // Text input field
                    HStack(alignment: .bottom, spacing: 8) {
                        TextField("Message", text: $text, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .lineLimit(1...6)
                            .focused($isFocused)
                            .onChange(of: text) { oldValue, newValue in
                                handleTyping(oldValue: oldValue, newValue: newValue)
                            }
                            .accessibilityIdentifier("messageInputField")
                    }
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(20)

                    // Send/Mic button
                    Button(action: handleSendOrRecord) {
                        Image(systemName: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .blue : .blue)
                    }
                    .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
                    .accessibilityIdentifier("sendButton")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .systemBackground))
            }
        }
    }

    private var recordingView: some View {
        VStack(spacing: 12) {
            // Waveform visualization
            RecordingWaveformView(samples: audioRecorder.waveformSamples)
                .frame(height: 50)
                .padding(.horizontal, 16)

            HStack(spacing: 20) {
                // Cancel button
                Button(action: cancelRecording) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.red)
                }

                Spacer()

                // Duration
                Text(audioRecorder.formatDuration(audioRecorder.recordingDuration))
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)

                Spacer()

                // Stop and send button
                Button(action: stopAndSendRecording) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 30)
        }
        .padding(.vertical, 16)
        .background(Color(uiColor: .systemBackground))
    }

    private func handleSendOrRecord() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            handleSend()
        } else {
            startRecording()
        }
    }

    private func handleSend() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        onSend()
        text = ""

        // Notify typing stopped
        typingTimer?.invalidate()
        onTypingChanged(false)
    }

    private func startRecording() {
        Task {
            do {
                _ = try await audioRecorder.startRecording()
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showRecordingUI = true
                    }
                }
            } catch {
                print("Failed to start recording: \(error)")
            }
        }
    }

    private func stopAndSendRecording() {
        guard let recording = audioRecorder.stopRecording() else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showRecordingUI = false
        }

        onAudioSend(recording.url, recording.duration, recording.waveform)
    }

    private func cancelRecording() {
        audioRecorder.cancelRecording()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showRecordingUI = false
        }
    }

    private func handleTyping(oldValue: String, newValue: String) {
        // Cancel existing timer
        typingTimer?.invalidate()

        if !newValue.isEmpty {
            // User is typing
            onTypingChanged(true)

            // Set timer to stop typing after 2 seconds of inactivity
            typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                onTypingChanged(false)
            }
        } else {
            // Text is empty, stop typing
            onTypingChanged(false)
        }
    }

    private func toggleSuggestedReplies() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showSuggestedReplies.toggle()
        }
    }

    private func handleSuggestedReply(_ reply: String) {
        text = reply
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showSuggestedReplies = false
        }
        onSuggestedReplyTap(reply)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack {
                Spacer()
                MessageInputBar(
                    text: $text,
                    isFocused: $isFocused,
                    onSend: { print("Send: \(text)") },
                    onAudioSend: { url, duration, waveform in
                        print("Audio: \(url), \(duration)s, \(waveform.count) samples")
                    },
                    onTypingChanged: { isTyping in print("Typing: \(isTyping)") },
                    suggestedReplies: ["Hola!", "¿Cómo estás?", "Sí, me gusta"],
                    onSuggestedReplyTap: { print("Selected: \($0)") }
                )
            }
        }
    }

    return PreviewWrapper()
}
