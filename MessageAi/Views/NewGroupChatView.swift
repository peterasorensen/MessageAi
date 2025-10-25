//
//  NewGroupChatView.swift
//  MessageAi
//
//  Created by Apple on 10/24/25.
//

import SwiftUI
import SwiftData

struct NewGroupChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var users: [User] = []
    @State private var selectedUserIds: Set<String> = []
    @State private var isLoading = true
    @State private var isCreating = false

    let authService: AuthService
    let messageService: MessageService
    let onConversationCreated: (Conversation) -> Void

    private var canCreateGroup: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedUserIds.count >= 2
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Group name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Group Name")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)

                    TextField("Enter group name", text: $groupName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 16)
                        .autocorrectionDisabled()
                }
                .padding(.vertical, 16)
                .background(Color(uiColor: .systemGroupedBackground))

                // Members section header
                HStack {
                    Text("Add Members")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(selectedUserIds.count) selected")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // User list
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if users.isEmpty {
                    Spacer()
                    Text("No users found")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(users, id: \.id) { user in
                            Button(action: {
                                toggleUserSelection(user.id)
                            }) {
                                HStack(spacing: 12) {
                                    // Selection indicator
                                    Image(systemName: selectedUserIds.contains(user.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 24))
                                        .foregroundStyle(selectedUserIds.contains(user.id) ? .blue : .gray.opacity(0.3))
                                        .animation(.easeInOut(duration: 0.2), value: selectedUserIds.contains(user.id))

                                    // Avatar
                                    AvatarView(
                                        name: user.displayName,
                                        avatarURL: user.avatarURL,
                                        size: 44,
                                        isOnline: user.isOnline
                                    )

                                    // User info
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(user.displayName)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.primary)

                                        if user.isOnline {
                                            Text("Online")
                                                .font(.system(size: 13))
                                                .foregroundStyle(.green)
                                        } else {
                                            Text("Offline")
                                                .font(.system(size: 13))
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(!canCreateGroup || isCreating)
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if isCreating {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Creating group...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(32)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(16)
                    }
                }
            }
        }
        .task {
            await loadUsers()
        }
    }

    private func toggleUserSelection(_ userId: String) {
        if selectedUserIds.contains(userId) {
            selectedUserIds.remove(userId)
        } else {
            selectedUserIds.insert(userId)
        }
    }

    private func loadUsers() async {
        do {
            let allUsers = try await authService.fetchUsers()
            users = allUsers.filter { $0.id != authService.currentUser?.id }
            isLoading = false
        } catch {
            print("Error loading users: \(error.localizedDescription)")
            isLoading = false
        }
    }

    private func createGroup() {
        guard let currentUserId = authService.currentUser?.id,
              let currentUserName = authService.currentUser?.displayName else {
            return
        }

        isCreating = true

        Task {
            do {
                let trimmedGroupName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)

                // Include current user in participant IDs
                var participantIds = Array(selectedUserIds)
                participantIds.append(currentUserId)

                // Build participant names dictionary
                var participantNames: [String: String] = [currentUserId: currentUserName]
                for user in users where selectedUserIds.contains(user.id) {
                    participantNames[user.id] = user.displayName
                }

                // Create group conversation
                let conversation = try await messageService.createConversation(
                    with: participantIds,
                    participantNames: participantNames,
                    type: .group
                )

                // Update group name and avatar
                try await messageService.updateGroupInfo(
                    conversationId: conversation.id,
                    groupName: trimmedGroupName,
                    groupAvatarURL: nil
                )

                await MainActor.run {
                    isCreating = false
                    onConversationCreated(conversation)
                    dismiss()
                }
            } catch {
                print("Error creating group: \(error.localizedDescription)")
                await MainActor.run {
                    isCreating = false
                }
            }
        }
    }
}

#Preview {
    NewGroupChatView(
        authService: AuthService(),
        messageService: MessageService(
            modelContext: ModelContext(
                try! ModelContainer(for: Conversation.self, Message.self, User.self)
            ),
            authService: AuthService(),
            translationService: TranslationService()
        ),
        onConversationCreated: { _ in }
    )
}
