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
    @Environment(\.dismiss) private var dismiss

    @State private var showLanguageOnboarding = false
    @State private var autoTranslateEnabled = false
    @State private var showClearCacheAlert = false

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
}
