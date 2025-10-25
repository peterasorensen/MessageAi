//
//  AuthService.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftData

@Observable
class AuthService {
    var currentUser: User?
    var isAuthenticated = false
    var authError: String?

    private let db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        setupAuthStateListener()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    await self?.loadUserProfile(uid: user.uid)
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }

    // MARK: - Authentication

    func signUp(email: String, password: String, displayName: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            // Create user profile in Firestore
            let newUser = User(
                id: result.user.uid,
                displayName: displayName,
                email: email,
                isOnline: true
            )

            try await saveUserProfile(newUser)

            await MainActor.run {
                self.currentUser = newUser
                self.isAuthenticated = true
            }
        } catch {
            await MainActor.run {
                self.authError = error.localizedDescription
            }
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await loadUserProfile(uid: result.user.uid)
        } catch {
            await MainActor.run {
                self.authError = error.localizedDescription
            }
            throw error
        }
    }

    func signOut() throws {
        // Update online status before signing out
        if let userId = currentUser?.id {
            Task {
                try? await updateOnlineStatus(userId: userId, isOnline: false)
            }
        }

        try Auth.auth().signOut()
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - User Profile Management

    private func loadUserProfile(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()

            if let data = document.data() {
                let userDTO = try Firestore.Decoder().decode(UserDTO.self, from: data)
                let user = userDTO.toUser()

                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                }

                // Update online status
                try? await updateOnlineStatus(userId: uid, isOnline: true)
            }
        } catch {
            print("Error loading user profile: \(error.localizedDescription)")
        }
    }

    func saveUserProfile(_ user: User) async throws {
        let userDTO = UserDTO(from: user)
        let data = try Firestore.Encoder().encode(userDTO)
        try await db.collection("users").document(user.id).setData(data)
    }

    func updateUserProfile(displayName: String? = nil, avatarURL: String? = nil) async throws {
        guard let user = currentUser else { return }

        var updates: [String: Any] = [:]
        if let displayName = displayName {
            updates["displayName"] = displayName
        }
        if let avatarURL = avatarURL {
            updates["avatarURL"] = avatarURL
        }

        try await db.collection("users").document(user.id).updateData(updates)

        // Update local user
        await MainActor.run {
            if let displayName = displayName {
                self.currentUser?.displayName = displayName
            }
            if let avatarURL = avatarURL {
                self.currentUser?.avatarURL = avatarURL
            }
        }
    }

    // MARK: - Online Status

    func updateOnlineStatus(userId: String, isOnline: Bool) async throws {
        let updates: [String: Any] = [
            "isOnline": isOnline,
            "lastSeen": Timestamp(date: Date())
        ]

        try await db.collection("users").document(userId).updateData(updates)

        await MainActor.run {
            self.currentUser?.isOnline = isOnline
            self.currentUser?.lastSeen = Date()
        }
    }

    // MARK: - Fetch Other Users

    func fetchUsers() async throws -> [User] {
        let snapshot = try await db.collection("users").getDocuments()

        return snapshot.documents.compactMap { document in
            try? Firestore.Decoder().decode(UserDTO.self, from: document.data()).toUser()
        }
    }

    func fetchUser(by id: String) async throws -> User? {
        let document = try await db.collection("users").document(id).getDocument()

        if let data = document.data() {
            let userDTO = try Firestore.Decoder().decode(UserDTO.self, from: data)
            return userDTO.toUser()
        }

        return nil
    }

    func listenToUser(userId: String, onChange: @escaping (User) -> Void) -> ListenerRegistration {
        return db.collection("users").document(userId).addSnapshotListener { snapshot, error in
            guard let data = snapshot?.data(),
                  let userDTO = try? Firestore.Decoder().decode(UserDTO.self, from: data) else {
                return
            }
            onChange(userDTO.toUser())
        }
    }
}
