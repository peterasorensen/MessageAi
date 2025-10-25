//
//  GroupInfoView.swift
//  MessageAi
//
//  Created by Apple on 10/24/25.
//

import SwiftUI

struct GroupInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupName: String
    @State private var isEditingName = false
    @State private var showingAddMembers = false
    @State private var isSaving = false

    let conversation: Conversation
    let authService: AuthService
    let messageService: MessageService

    init(conversation: Conversation, authService: AuthService, messageService: MessageService) {
        self.conversation = conversation
        self.authService = authService
        self.messageService = messageService
        _groupName = State(initialValue: conversation.groupName ?? "Unnamed Group")
    }

    private var currentUserId: String {
        authService.currentUser?.id ?? ""
    }

    private var members: [(id: String, name: String)] {
        conversation.participantIds.compactMap { userId in
            if let name = conversation.participantNames[userId] {
                return (id: userId, name: name)
            }
            return nil
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Group info section
                Section {
                    VStack(spacing: 16) {
                        // Group avatar
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 100, height: 100)

                            Image(systemName: "person.3.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)

                        // Group name
                        if isEditingName {
                            HStack {
                                TextField("Group name", text: $groupName)
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.center)

                                Button("Save") {
                                    saveGroupName()
                                }
                                .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        } else {
                            HStack {
                                Text(conversation.groupName ?? "Unnamed Group")
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Button(action: { isEditingName = true }) {
                                    Image(systemName: "pencil")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }

                        Text("\(conversation.participantIds.count) members")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }

                // Members section
                Section {
                    ForEach(members, id: \.id) { member in
                        HStack(spacing: 12) {
                            AvatarView(
                                name: member.name,
                                size: 44,
                                isOnline: messageService.onlineUsers[member.id] ?? false
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(member.name)
                                        .font(.system(size: 16, weight: .medium))

                                    if member.id == currentUserId {
                                        Text("(You)")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if messageService.onlineUsers[member.id] ?? false {
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

                    // Add members button
                    Button(action: { showingAddMembers = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.blue)

                            Text("Add Member")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text("\(members.count) Members")
                }

                // Actions section
                Section {
                    Button(role: .destructive, action: leaveGroup) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Leave Group")
                        }
                    }
                }
            }
            .navigationTitle("Group Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddMembers) {
                AddGroupMembersView(
                    conversation: conversation,
                    authService: authService,
                    messageService: messageService
                )
            }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(32)
                            .background(Color(uiColor: .systemBackground))
                            .cornerRadius(16)
                    }
                }
            }
        }
    }

    private func saveGroupName() {
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isSaving = true

        Task {
            do {
                try await messageService.updateGroupInfo(
                    conversationId: conversation.id,
                    groupName: trimmedName,
                    groupAvatarURL: nil
                )

                await MainActor.run {
                    isEditingName = false
                    isSaving = false
                }
            } catch {
                print("Error updating group name: \(error.localizedDescription)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }

    private func leaveGroup() {
        Task {
            do {
                try await messageService.deleteConversation(conversationId: conversation.id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error leaving group: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Add Group Members View

struct AddGroupMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var users: [User] = []
    @State private var selectedUserIds: Set<String> = []
    @State private var isLoading = true
    @State private var isAdding = false

    let conversation: Conversation
    let authService: AuthService
    let messageService: MessageService

    private var availableUsers: [User] {
        users.filter { user in
            !conversation.participantIds.contains(user.id)
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView()
                } else if availableUsers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray.opacity(0.5))

                        Text("No users to add")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("All users are already in this group")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(availableUsers, id: \.id) { user in
                            Button(action: {
                                toggleUserSelection(user.id)
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedUserIds.contains(user.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 24))
                                        .foregroundStyle(selectedUserIds.contains(user.id) ? .blue : .gray.opacity(0.3))

                                    AvatarView(
                                        name: user.displayName,
                                        avatarURL: user.avatarURL,
                                        size: 44,
                                        isOnline: user.isOnline
                                    )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(user.displayName)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.primary)

                                        Text(user.isOnline ? "Online" : "Offline")
                                            .font(.system(size: 13))
                                            .foregroundStyle(user.isOnline ? .green : .secondary)
                                    }

                                    Spacer()
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addMembers()
                    }
                    .disabled(selectedUserIds.isEmpty || isAdding)
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

    private func addMembers() {
        isAdding = true

        Task {
            do {
                try await messageService.addGroupMembers(
                    conversationId: conversation.id,
                    userIds: Array(selectedUserIds)
                )

                await MainActor.run {
                    isAdding = false
                    dismiss()
                }
            } catch {
                print("Error adding members: \(error.localizedDescription)")
                await MainActor.run {
                    isAdding = false
                }
            }
        }
    }
}
