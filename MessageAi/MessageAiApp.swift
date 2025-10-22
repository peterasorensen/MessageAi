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
    @State private var authService = AuthService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Conversation.self,
            Message.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Initialize Firebase
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
        }
        .modelContainer(sharedModelContainer)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService

    var body: some View {
        Group {
            if authService.isAuthenticated {
                ConversationListView(
                    authService: authService,
                    messageService: MessageService(
                        modelContext: modelContext,
                        authService: authService
                    )
                )
            } else {
                LoginView(authService: authService)
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
    }
}
