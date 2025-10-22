//
//  LoginView.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import SwiftUI

struct LoginView: View {
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    let authService: AuthService

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App logo/icon
                VStack(spacing: 12) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 10)

                    Text("MessageAi")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 60)

                // Auth form
                VStack(spacing: 20) {
                    if isSignUp {
                        authField(
                            icon: "person.fill",
                            placeholder: "Display Name",
                            text: $displayName
                        )
                    }

                    authField(
                        icon: "envelope.fill",
                        placeholder: "Email",
                        text: $email,
                        keyboardType: .emailAddress
                    )

                    authField(
                        icon: "lock.fill",
                        placeholder: "Password",
                        text: $password,
                        isSecure: true
                    )

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // Primary action button
                    Button(action: handleAuth) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white.opacity(0.25))
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || !isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.6)
                    .padding(.top, 10)

                    // Toggle between sign in/sign up
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isSignUp.toggle()
                            errorMessage = nil
                        }
                    }) {
                        Text(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Sign up")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
    }

    private func authField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        isSecure: Bool = false
    ) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: text)
                    .textContentType(.password)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .textContentType(keyboardType == .emailAddress ? .emailAddress : .none)
                    .autocapitalization(.none)
            }
        }
        .foregroundStyle(.white)
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
    }

    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && !displayName.isEmpty && password.count >= 6
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }

    private func handleAuth() {
        guard isFormValid else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                if isSignUp {
                    try await authService.signUp(email: email, password: password, displayName: displayName)
                } else {
                    try await authService.signIn(email: email, password: password)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    LoginView(authService: AuthService())
}
