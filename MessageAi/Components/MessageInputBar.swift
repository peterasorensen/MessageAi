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
    let onTypingChanged: (Bool) -> Void

    @State private var typingTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .bottom, spacing: 12) {
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

                // Send button
                Button(action: handleSend) {
                    Image(systemName: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
                .accessibilityIdentifier("sendButton")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemBackground))
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
                    onTypingChanged: { isTyping in print("Typing: \(isTyping)") }
                )
            }
        }
    }

    return PreviewWrapper()
}
