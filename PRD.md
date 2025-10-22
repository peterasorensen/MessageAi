**Intro**
I'm creating a messaging app. Can you help me create a simple chat app with a user
interface similar to Signal. Focus on simplicity right now, skip encryption and other things. Use the technical stack below for auth and for realtime messaging.

### **MVP Requirements (24 Hours)**

This is a hard gate. To pass the MVP checkpoint, you must have:

* One-on-one chat functionality  
* Real-time message delivery between 2+ users  
* Message persistence (survives app restarts)  
* Optimistic UI updates (messages appear instantly before server confirmation)  
* Online/offline status indicators  
* Message timestamps  
* User authentication (users have accounts/profiles)  
* Basic group chat functionality (3+ users in one conversation)  
* Message read receipts  
* Push notifications working (at least in foreground)  
* **Deployment**: Running on local emulator/simulator with deployed backend (TestFlight/APK/Expo Go if possible, but not required for MVP)

## **Core Messaging Infrastructure**

### **Essential Features**

Your messaging app needs one-on-one chat with real-time message delivery. Messages must persist locally—users should see their chat history even when offline. Support text messages with timestamps and read receipts.

Implement online/offline presence indicators. Show when users are typing. Handle message delivery states: sending, sent, delivered, read.

Include basic media support—at minimum, users should be able to send and receive images. Add profile pictures and display names.

Build group chat functionality supporting 3+ users with proper message attribution and delivery tracking.

### **Real-Time Messaging**

Every message should appear instantly for online recipients. When users go offline, messages queue and send when connectivity returns. The app must handle poor network conditions gracefully—3G, packet loss, intermittent connectivity.

Implement optimistic UI updates. When users send a message, it appears immediately in their chat, then updates with delivery confirmation. Messages never get lost—if the app crashes mid-send, the message should still go out.

## **Technical Stack (Recommended)**

### **The Golden Path: Firebase \+ Swift**
**Backend:**

* **Firebase Firestore** \- real-time database  
* **Firebase Cloud Functions** \- serverless backend for AI calls  
* **Firebase Auth** \- user authentication  
* **Firebase Cloud Messaging (FCM)** \- push notifications

**Mobile (iOS):**

* **Swift** with SwiftUI  
* **SwiftData** for local storage  
* **URLSession** for networking  
* **Firebase SDK**  
* Deploy via **TestFlight**