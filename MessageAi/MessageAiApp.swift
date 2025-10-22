//
//  MessageAiApp.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct MessageAiApp: App {
    init() {
        // Configure Firebase BEFORE any @State properties are initialized
        FirebaseApp.configure()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Conversation.self,
            Message.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If migration fails, delete the old store and create a fresh one
            print("⚠️ ModelContainer creation failed, attempting to delete old store: \(error)")

            // Delete old store
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)
            print("🗑️ Deleted old store at: \(url)")

            // Try again with fresh store
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after deleting old store: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct ContentView: View {
    @State private var authService = AuthService()

    var body: some View {
        RootView()
            .environment(authService)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @State private var messageService: MessageService?

    var body: some View {
        Group {
            if authService.isAuthenticated {
                if let messageService = messageService {
                    ConversationListView(
                        authService: authService,
                        messageService: messageService
                    )
                    .transition(.opacity)
                }
            } else {
                LoginView(authService: authService)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .onAppear {
            if messageService == nil {
                messageService = MessageService(modelContext: modelContext, authService: authService)
            }
        }
    }
}
