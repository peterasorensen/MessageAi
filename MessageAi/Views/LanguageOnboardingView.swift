//
//  LanguageOnboardingView.swift
//  MessageAi
//
//  Created by Apple on 10/24/25.
//

import SwiftUI

struct LanguageOnboardingView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var selectedTargetLanguage: Language?
    @State private var selectedFluentLanguage: Language?
    @State private var autoTranslateEnabled = false

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

    var body: some View {
        VStack {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<4) { step in
                    Capsule()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            TabView(selection: $currentStep) {
                // Step 1: Welcome
                welcomeStep.tag(0)

                // Step 2: Target Language (learning)
                targetLanguageStep.tag(1)

                // Step 3: Fluent Language
                fluentLanguageStep.tag(2)

                // Step 4: Auto-translate preference
                autoTranslateStep.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)
        }
    }

    // MARK: - Step Views

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🌍")
                .font(.system(size: 80))

            Text("Welcome to MessageAi Translation")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Learn languages naturally through conversations. Get instant translations and detailed word explanations.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                withAnimation {
                    currentStep = 1
                }
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private var targetLanguageStep: some View {
        VStack(spacing: 24) {
            Text("What language are you learning?")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 40)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                    ForEach(languages) { language in
                        LanguageCard(
                            language: language,
                            isSelected: selectedTargetLanguage?.code == language.code
                        ) {
                            selectedTargetLanguage = language
                        }
                    }
                }
                .padding()
            }

            Button {
                withAnimation {
                    if selectedTargetLanguage != nil {
                        currentStep = 2
                    }
                }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedTargetLanguage != nil ? Color.blue : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(selectedTargetLanguage == nil)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private var fluentLanguageStep: some View {
        VStack(spacing: 24) {
            Text("What's your native language?")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 40)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                    ForEach(languages) { language in
                        LanguageCard(
                            language: language,
                            isSelected: selectedFluentLanguage?.code == language.code
                        ) {
                            selectedFluentLanguage = language
                        }
                    }
                }
                .padding()
            }

            HStack {
                Button {
                    withAnimation {
                        currentStep = 1
                    }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    withAnimation {
                        if selectedFluentLanguage != nil {
                            currentStep = 3
                        }
                    }
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedFluentLanguage != nil ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedFluentLanguage == nil)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private var autoTranslateStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🔄")
                .font(.system(size: 60))

            Text("Auto-Translate Messages")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Automatically translate all incoming messages into \(selectedTargetLanguage?.name ?? "your target language"). You can toggle this anytime in settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Toggle("Enable Auto-Translate", isOn: $autoTranslateEnabled)
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

            Spacer()

            HStack {
                Button {
                    withAnimation {
                        currentStep = 2
                    }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    Task {
                        await savePreferences()
                    }
                } label: {
                    Text("Finish")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Actions

    private func savePreferences() async {
        guard let targetLanguage = selectedTargetLanguage,
              let fluentLanguage = selectedFluentLanguage,
              let user = authService.currentUser else {
            return
        }

        user.targetLanguage = targetLanguage.code
        user.fluentLanguage = fluentLanguage.code
        user.autoTranslateEnabled = autoTranslateEnabled
        user.needsOnboarding = false

        try? await authService.updateUserProfile(
            displayName: user.displayName,
            phoneNumber: user.phoneNumber,
            avatarURL: user.avatarURL,
            targetLanguage: targetLanguage.code,
            fluentLanguage: fluentLanguage.code,
            autoTranslateEnabled: autoTranslateEnabled
        )

        dismiss()
    }
}

// MARK: - Supporting Views

struct LanguageCard: View {
    let language: Language
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(language.flag)
                    .font(.system(size: 40))
                Text(language.name)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(width: 100, height: 100)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct Language: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let flag: String
}
