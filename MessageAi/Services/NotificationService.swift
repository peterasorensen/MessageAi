//
//  NotificationService.swift
//  MessageAi
//
//  Created by Apple on 10/24/25.
//

import Foundation
import FirebaseFirestore
import UserNotifications

@Observable
class NotificationService {
    private let db = Firestore.firestore()
    private var fcmToken: String?

    init() {
        // Listen for FCM token updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFCMTokenUpdate),
            name: NSNotification.Name("FCMTokenUpdated"),
            object: nil
        )

        // Load existing token from UserDefaults
        self.fcmToken = UserDefaults.standard.string(forKey: "fcmToken")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - FCM Token Management

    @objc private func handleFCMTokenUpdate(notification: Notification) {
        if let token = notification.userInfo?["token"] as? String {
            self.fcmToken = token
            print("📲 FCM Token updated in NotificationService: \(token)")
        }
    }

    func updateFCMToken(userId: String) async throws {
        guard let token = fcmToken else {
            print("⚠️ No FCM token available to update")
            return
        }

        print("🔄 Updating FCM token for user: \(userId)")

        try await db.collection("users")
            .document(userId)
            .updateData(["fcmToken": token])

        print("✅ FCM token updated in Firestore")
    }

    // MARK: - Send Notifications

    /// Send a push notification to specific users
    /// Note: This creates a Firestore document that triggers a Cloud Function to send the actual FCM notification
    func sendNotification(
        to userIds: [String],
        title: String,
        body: String,
        conversationId: String,
        messageId: String
    ) async throws {
        print("📤 Sending notification to users: \(userIds)")

        // Create notification document in Firestore
        // This will be picked up by a Cloud Function (or Cloud Firestore trigger) to send FCM
        let notification: [String: Any] = [
            "recipientIds": userIds,
            "title": title,
            "body": body,
            "conversationId": conversationId,
            "messageId": messageId,
            "timestamp": Timestamp(date: Date()),
            "sent": false // Cloud Function will set this to true after sending
        ]

        try await db.collection("notifications")
            .addDocument(data: notification)

        print("✅ Notification document created in Firestore")
    }

    /// Alternative: Send notification directly via FCM (requires fetching FCM tokens)
    func sendDirectNotification(
        to userIds: [String],
        title: String,
        body: String,
        conversationId: String,
        messageId: String
    ) async throws {
        print("📤 Preparing direct FCM notification")

        // Fetch FCM tokens for the recipient users
        var fcmTokens: [String] = []

        for userId in userIds {
            let doc = try await db.collection("users").document(userId).getDocument()
            if let token = doc.data()?["fcmToken"] as? String {
                fcmTokens.append(token)
            }
        }

        guard !fcmTokens.isEmpty else {
            print("⚠️ No FCM tokens found for recipients")
            return
        }

        print("📱 Found \(fcmTokens.count) FCM tokens")

        // Note: Direct FCM sending from iOS client requires Firebase Cloud Functions or a backend
        // For now, we'll use the Firestore trigger approach above
        // If you want direct sending, you'll need to implement a Cloud Function that accepts
        // HTTP requests with the notification payload
    }

    // MARK: - Request Permissions

    func requestNotificationPermissions() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])

            print("📲 Notification permission: \(granted ? "✅ Granted" : "❌ Denied")")
            return granted
        } catch {
            print("❌ Error requesting notification permissions: \(error.localizedDescription)")
            return false
        }
    }

    func checkNotificationPermissions() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}
