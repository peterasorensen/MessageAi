//
//  MessageAiApp.swift
//  MessageAi
//
//  Created by Apple on 10/21/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseMessaging

@main
struct MessageAiApp: App {
    // Connect the AppDelegate for notification handling
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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

        // Use in-memory store to avoid migration issues with Array types
        // Firestore is the source of truth, so we don't need persistent local storage
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("⚠️ ModelContainer creation failed: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var messageService: MessageService?
    @State private var notificationService = NotificationService()

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

            // Set user online when app appears
            if let userId = authService.currentUser?.id {
                Task {
                    try? await authService.updateOnlineStatus(userId: userId, isOnline: true)
                    print("✅ User set to ONLINE on app appear")

                    // Update FCM token for this user
                    try? await notificationService.updateFCMToken(userId: userId)
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            guard let userId = authService.currentUser?.id else { return }

            switch newPhase {
            case .active:
                // App became active - set online
                Task {
                    try? await authService.updateOnlineStatus(userId: userId, isOnline: true)
                    print("✅ User set to ONLINE (app active)")
                }
            case .background, .inactive:
                // App went to background or became inactive - set offline
                Task {
                    try? await authService.updateOnlineStatus(userId: userId, isOnline: false)
                    print("🔴 User set to OFFLINE (app \(newPhase == .background ? "background" : "inactive"))")
                }
            @unknown default:
                break
            }
        }
    }
}
