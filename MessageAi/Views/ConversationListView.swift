//
//  ConversationListView.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewChat = false
    @State private var showingNewGroup = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()
    @State private var selectedConversation: Conversation?

    let authService: AuthService
    let messageService: MessageService

    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return messageService.conversations
        } else {
            return messageService.conversations.filter { conversation in
                conversation.otherParticipantName(currentUserId: authService.currentUser?.id ?? "")
                    .localizedCaseInsensitiveContains(searchText) ||
                conversation.lastMessage.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if messageService.conversations.isEmpty {
                    emptyStateView
                } else {
                    conversationList
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button(action: { showingSettings = true }) {
                            Label("Settings", systemImage: "gearshape")
                        }
                        Button(role: .destructive, action: handleSignOut) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        AvatarView(
                            name: authService.currentUser?.displayName ?? "",
                            avatarURL: authService.currentUser?.avatarURL,
                            size: 32
                        )
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { showingNewChat = true }) {
                            Label("New Chat", systemImage: "bubble.left.and.bubble.right")
                        }
                        Button(action: { showingNewGroup = true }) {
                            Label("New Group", systemImage: "person.3")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search conversations")
            .sheet(isPresented: $showingNewChat) {
                NewChatView(
                    authService: authService,
                    messageService: messageService,
                    onConversationCreated: { conversation in
                        selectedConversation = conversation
                        showingNewChat = false
                    }
                )
            }
            .sheet(isPresented: $showingNewGroup) {
                NewGroupChatView(
                    authService: authService,
                    messageService: messageService,
                    onConversationCreated: { conversation in
                        selectedConversation = conversation
                        showingNewGroup = false
                    }
                )
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatView(
                    conversation: conversation,
                    authService: authService,
                    messageService: messageService
                )
            }
        }
        .onAppear {
            if let userId = authService.currentUser?.id {
                messageService.startListeningToConversations(userId: userId)
                // Start listening to all participants' presence
                messageService.startListeningToAllParticipantsPresence()
            }
        }
        .onChange(of: messageService.conversations) { _, newConversations in
            // When conversations update, ensure we're listening to all participants
            messageService.startListeningToAllParticipantsPresence()
        }
    }

    private var conversationList: some View {
        List {
            ForEach(filteredConversations, id: \.id) { conversation in
                NavigationLink(destination: ChatView(
                    conversation: conversation,
                    authService: authService,
                    messageService: messageService
                )) {
                    ConversationRow(
                        conversation: conversation,
                        currentUserId: authService.currentUser?.id ?? "",
                        messageService: messageService
                    )
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteConversation(conversation)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .listStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: filteredConversations.count)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message")
                .font(.system(size: 70))
                .foregroundStyle(.gray.opacity(0.5))

            Text("No conversations yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text("Start a new conversation by tapping the compose button")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showingNewChat = true }) {
                Label("New Conversation", systemImage: "square.and.pencil")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
        }
    }

    private func handleSignOut() {
        do {
            try authService.signOut()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }

    private func deleteConversation(_ conversation: Conversation) {
        Task {
            do {
                try await messageService.deleteConversation(conversationId: conversation.id)
            } catch {
                print("Error deleting conversation: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    let currentUserId: String
    let messageService: MessageService

    private var otherUserId: String? {
        conversation.otherParticipantId(currentUserId: currentUserId)
    }

    private var isOtherUserOnline: Bool {
        guard let userId = otherUserId else { return false }
        return messageService.onlineUsers[userId] ?? false
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar (group or individual)
            if conversation.conversationType == .group {
                // Group avatar
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 54, height: 54)

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue)
                }
            } else {
                // Individual avatar
                AvatarView(
                    name: conversation.otherParticipantName(currentUserId: currentUserId),
                    size: 54,
                    isOnline: isOtherUserOnline
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                // Name and timestamp
                HStack {
                    Text(conversation.otherParticipantName(currentUserId: currentUserId))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(formatTimestamp(conversation.lastMessageTimestamp))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                // Last message and unread count
                HStack {
                    Text(conversation.lastMessage.isEmpty ? "No messages yet" : conversation.lastMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(conversation.unreadCount > 0 ? .primary : .secondary)
                        .lineLimit(1)

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }

                // Typing indicator (only show if OTHER users are typing)
                if !conversation.isTyping.isEmpty && !conversation.isTyping.contains(currentUserId) {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                                .scaleEffect(1.0)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: UUID()
                                )
                        }
                        Text("typing...")
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return date.formatted(Date.FormatStyle().weekday(.abbreviated))
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

// MARK: - New Chat View

struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var users: [User] = []
    @State private var isLoading = true

    let authService: AuthService
    let messageService: MessageService
    let onConversationCreated: (Conversation) -> Void

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if users.isEmpty {
                    Text("No users found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(users, id: \.id) { user in
                        Button(action: {
                            startConversation(with: user)
                        }) {
                            HStack(spacing: 12) {
                                AvatarView(
                                    name: user.displayName,
                                    avatarURL: user.avatarURL,
                                    size: 50,
                                    isOnline: user.isOnline
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName)
                                        .font(.system(size: 16, weight: .semibold))
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
            }
            .listStyle(.plain)
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadUsers()
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

    private func startConversation(with user: User) {
        Task {
            do {
                let conversation = try await messageService.getOrCreateConversation(with: user.id, userName: user.displayName)
                await MainActor.run {
                    onConversationCreated(conversation)
                    dismiss()
                }
            } catch {
                print("Error creating conversation: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    ConversationListView(
        authService: AuthService(),
        messageService: MessageService(
            modelContext: ModelContext(try! ModelContainer(for: Conversation.self, Message.self, User.self)),
            authService: AuthService(),
            translationService: TranslationService()
        )
    )
}
