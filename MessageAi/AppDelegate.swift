//
//  AppDelegate.swift
//  MessageAi
//
//  Created by Apple on 10/24/25.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Set up notification delegates
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("📲 Notification permission granted: \(granted)")
            if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            }
        }

        // Register for remote notifications
        application.registerForRemoteNotifications()

        return true
    }

    // MARK: - Remote Notifications Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 Registered for remote notifications")
        // Pass the device token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - Firebase Messaging Delegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📩 FCM Token: \(fcmToken ?? "nil")")

        // Store the FCM token in UserDefaults for later use
        if let token = fcmToken {
            UserDefaults.standard.set(token, forKey: "fcmToken")

            // Post notification so other parts of app can update Firestore
            NotificationCenter.default.post(
                name: NSNotification.Name("FCMTokenUpdated"),
                object: nil,
                userInfo: ["token": token]
            )
        }
    }

    // MARK: - Notification Handling

    // This is called when a notification is received while the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        let userInfo = notification.request.content.userInfo
        print("📬 Received notification in foreground: \(userInfo)")

        // Handle message delivery in background
        handleNotificationDelivery(userInfo: userInfo)

        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // This is called when user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {

        let userInfo = response.notification.request.content.userInfo
        print("👆 User tapped notification: \(userInfo)")

        // Handle message delivery
        handleNotificationDelivery(userInfo: userInfo)

        // Extract conversation ID and post notification to open that conversation
        if let conversationId = userInfo["conversationId"] as? String {
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenConversation"),
                object: nil,
                userInfo: ["conversationId": conversationId]
            )
        }

        completionHandler()
    }

    // MARK: - Background Notification Handler

    private func handleNotificationDelivery(userInfo: [AnyHashable: Any]) {
        // Extract message metadata from notification
        guard let conversationId = userInfo["conversationId"] as? String,
              let messageId = userInfo["messageId"] as? String else {
            print("⚠️ Missing conversation or message ID in notification payload")
            return
        }

        print("📥 Marking message as delivered: \(messageId) in conversation: \(conversationId)")

        // Post notification to MessageService to handle delivery update
        NotificationCenter.default.post(
            name: NSNotification.Name("MarkMessageDelivered"),
            object: nil,
            userInfo: [
                "conversationId": conversationId,
                "messageId": messageId
            ]
        )
    }
}
