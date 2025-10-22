# MessageAi Setup Guide

This guide will help you set up Firebase and get MessageAi running.

## Step 1: Add Firebase SDK to Xcode

1. **Open your project in Xcode**
   - Open `MessageAi.xcodeproj`

2. **Add Firebase Swift Package**
   - In Xcode, go to `File` → `Add Package Dependencies...`
   - Enter the Firebase iOS SDK URL: `https://github.com/firebase/firebase-ios-sdk`
   - Click `Add Package`
   - Select the following packages:
     - ✅ FirebaseAuth
     - ✅ FirebaseFirestore
     - ✅ FirebaseMessaging (for push notifications)
   - Click `Add Package`

## Step 2: Create Firebase Project

1. **Go to Firebase Console**
   - Visit [https://console.firebase.google.com/](https://console.firebase.google.com/)
   - Click "Add project" or select an existing project

2. **Create a new project**
   - Project name: `MessageAi` (or your preferred name)
   - Enable Google Analytics (optional but recommended)
   - Click "Create project"

## Step 3: Add iOS App to Firebase

1. **Register your iOS app**
   - In Firebase Console, click the iOS icon (⊕)
   - Bundle ID: `com.yourcompany.MessageAi` (use your actual bundle ID from Xcode)
     - To find your bundle ID in Xcode: Select your project → Target → General → Bundle Identifier
   - App nickname: `MessageAi` (optional)
   - Click "Register app"

2. **Download GoogleService-Info.plist**
   - Download the `GoogleService-Info.plist` file
   - **IMPORTANT**: Drag this file into your Xcode project
     - Place it in the `MessageAi` folder (next to `MessageAiApp.swift`)
     - Make sure "Copy items if needed" is checked
     - Make sure your target is selected

## Step 4: Configure Firebase Authentication

1. **Enable Email/Password Authentication**
   - In Firebase Console, go to `Build` → `Authentication`
   - Click "Get started"
   - Go to `Sign-in method` tab
   - Click "Email/Password"
   - Enable both switches:
     - ✅ Email/Password
     - ✅ Email link (passwordless sign-in) - optional
   - Click "Save"

## Step 5: Configure Firestore Database

1. **Create Firestore Database**
   - In Firebase Console, go to `Build` → `Firestore Database`
   - Click "Create database"
   - Select "Start in **test mode**" (for development)
     - **Note**: You'll want to update security rules for production
   - Choose a location (select closest to your users)
   - Click "Enable"

2. **Set up Security Rules** (Optional but recommended)
   - Go to `Rules` tab
   - Replace with these rules for better security:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own user document
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // Conversations can be read/written by participants
    match /conversations/{conversationId} {
      allow read: if request.auth != null &&
                     request.auth.uid in resource.data.participantIds;
      allow create: if request.auth != null &&
                       request.auth.uid in request.resource.data.participantIds;
      allow update: if request.auth != null &&
                       request.auth.uid in resource.data.participantIds;

      // Messages within conversations
      match /messages/{messageId} {
        allow read: if request.auth != null &&
                       request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
        allow create: if request.auth != null &&
                         request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
        allow update: if request.auth != null &&
                         request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
      }
    }
  }
}
```

## Step 6: Build and Run

1. **Build the project**
   - In Xcode, select your target device or simulator
   - Press `Cmd + B` to build
   - Fix any build errors if they appear

2. **Run the app**
   - Press `Cmd + R` to run
   - The app should launch with the login screen

## Step 7: Test the App

1. **Create test accounts**
   - In the app, tap "Don't have an account? Sign up"
   - Create Account 1:
     - Display Name: "Alice"
     - Email: `alice@test.com`
     - Password: `password123`
   - Create Account 2 (use different simulator/device or sign out first):
     - Display Name: "Bob"
     - Email: `bob@test.com`
     - Password: `password123`

2. **Start a conversation**
   - Sign in as Alice
   - Tap the compose button (pencil icon)
   - Select Bob from the user list
   - Send a message
   - See real-time delivery!

3. **Test on second device**
   - Sign in as Bob on another simulator or device
   - See Alice's message appear
   - Reply to test two-way messaging

## Troubleshooting

### Build Errors

**Error: "No such module 'FirebaseAuth'"**
- Make sure you added the Firebase packages correctly
- Clean build folder: `Cmd + Shift + K`
- Rebuild: `Cmd + B`

**Error: "GoogleService-Info.plist not found"**
- Make sure you dragged the file into Xcode
- Check it appears in the project navigator
- Check "Copy Bundle Resources" in Build Phases

### Runtime Errors

**Error: "FirebaseApp.configure() must be called"**
- Already handled in `MessageAiApp.swift`
- Make sure Firebase packages are installed

**Error: "Permission denied" when writing to Firestore**
- Check Firestore security rules
- Make sure you're authenticated
- Verify user is in conversation participantIds

### Authentication Issues

**Can't sign up**
- Check Firebase Console → Authentication is enabled
- Check email/password provider is enabled
- Check internet connection

**Can't sign in**
- Verify credentials are correct
- Check Firebase Console → Authentication → Users to see registered users

## Next Steps

### Push Notifications (Optional)

1. Enable Firebase Cloud Messaging in Firebase Console
2. Add APNs authentication key
3. Request notification permissions in app
4. Handle notification payloads

### Production Deployment

1. **Security Rules**: Update Firestore rules for production
2. **Environment Config**: Separate dev/prod Firebase projects
3. **TestFlight**: Deploy via TestFlight for beta testing
4. **App Store**: Submit to App Store

## Features Implemented ✅

- ✅ Email/Password Authentication
- ✅ Real-time messaging with Firestore
- ✅ One-on-one chat
- ✅ Message persistence (SwiftData)
- ✅ Optimistic UI updates
- ✅ Online/offline indicators
- ✅ Message timestamps
- ✅ Read receipts
- ✅ Typing indicators
- ✅ Delivery states (sending/sent/delivered/read)
- ✅ Beautiful Signal-inspired UI

## Need Help?

- Firebase Documentation: https://firebase.google.com/docs/ios/setup
- SwiftUI Documentation: https://developer.apple.com/documentation/swiftui
- SwiftData Documentation: https://developer.apple.com/documentation/swiftdata
