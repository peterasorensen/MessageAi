# MessageAi File Reference

Quick reference for all files in the project.

## 📱 Main App

### MessageAiApp.swift
- **Purpose**: App entry point
- **Key Features**:
  - Firebase initialization
  - SwiftData ModelContainer setup
  - Auth state routing (LoginView vs ConversationListView)
- **Lines**: ~65

## 📦 Models (Data Layer)

### Models/User.swift
- **Purpose**: User data model
- **Key Features**:
  - SwiftData @Model for local storage
  - UserDTO for Firestore sync
  - Online status tracking
- **Properties**: id, displayName, email, phoneNumber, avatarURL, isOnline, lastSeen, createdAt
- **Lines**: ~75

### Models/Conversation.swift
- **Purpose**: Chat conversation model
- **Key Features**:
  - Supports one-on-one and group chats
  - Unread count tracking
  - Typing indicators
  - Last message preview
- **Properties**: id, type, participantIds, participantNames, lastMessage, unreadCount, isTyping, groupName
- **Lines**: ~120

### Models/Message.swift
- **Purpose**: Individual message model
- **Key Features**:
  - Message status states (sending, sent, delivered, read)
  - Optimistic UI support
  - Read receipt tracking
- **Enums**: MessageStatus, MessageType
- **Properties**: id, conversationId, senderId, content, status, timestamp, readBy, isOptimistic
- **Lines**: ~100

## 🔧 Services (Business Logic)

### Services/AuthService.swift
- **Purpose**: Firebase Authentication management
- **Key Features**:
  - Email/password sign up/sign in
  - User profile CRUD
  - Online/offline status updates
  - Auth state listening
- **Methods**:
  - `signUp(email:password:displayName:)`
  - `signIn(email:password:)`
  - `signOut()`
  - `updateOnlineStatus(userId:isOnline:)`
  - `fetchUsers()` - Get all users
- **Lines**: ~170

### Services/MessageService.swift
- **Purpose**: Firestore real-time messaging
- **Key Features**:
  - Real-time conversation listener
  - Real-time message listener
  - Optimistic message sending
  - Read receipt tracking
  - Typing indicators
  - SwiftData sync
- **Methods**:
  - `startListeningToConversations(userId:)`
  - `startListeningToMessages(conversationId:)`
  - `sendMessage(conversationId:content:)`
  - `markMessagesAsRead(conversationId:userId:)`
  - `setTyping(conversationId:userId:isTyping:)`
  - `createConversation(with:participantNames:)`
- **Lines**: ~280

## 🎨 Views (UI Screens)

### Views/LoginView.swift
- **Purpose**: Authentication screen
- **Key Features**:
  - Beautiful gradient background
  - Toggle between sign up/sign in
  - Input validation
  - Loading states
  - Error handling
- **UI Elements**:
  - App logo
  - Email field
  - Password field
  - Display name field (sign up only)
  - Submit button
  - Mode toggle button
- **Lines**: ~165

### Views/ConversationListView.swift
- **Purpose**: Main chat list screen
- **Key Features**:
  - List of conversations
  - Search functionality
  - New chat button
  - User menu with sign out
  - Empty state
  - Swipe actions
- **Sub-Views**:
  - ConversationRow - Individual chat row
  - NewChatView - User selection sheet
- **UI Elements**:
  - Navigation bar with avatar menu
  - Search bar
  - Conversation list
  - Compose button
- **Lines**: ~370

### Views/ChatView.swift
- **Purpose**: Individual chat conversation screen
- **Key Features**:
  - Scrollable message list
  - Real-time message updates
  - Typing indicator
  - Auto-scroll to bottom
  - Message input bar
  - Haptic feedback
- **UI Elements**:
  - Message list (ScrollView)
  - Typing indicator
  - Message input bar
  - Navigation title with status
- **Lines**: ~160

## 🧩 Components (Reusable UI)

### Components/AvatarView.swift
- **Purpose**: User avatar component
- **Key Features**:
  - Shows profile image or colored initials
  - Online status indicator (green dot)
  - Configurable size
  - Gradient placeholder
- **Parameters**: name, avatarURL, size, isOnline
- **Lines**: ~90

### Components/MessageRow.swift
- **Purpose**: Individual message bubble
- **Key Features**:
  - Sent vs received styling
  - Message status indicators
  - Timestamps
  - Sender name (for groups)
  - Read receipts
- **Status Icons**:
  - Clock = Sending
  - 1 Check = Sent
  - 2 Checks = Delivered
  - 2 Blue Checks = Read
  - Red ! = Failed
- **Lines**: ~135

### Components/MessageInputBar.swift
- **Purpose**: Message composition input
- **Key Features**:
  - Multi-line text input
  - Send button with animation
  - Typing detection
  - Auto-debounced typing indicator
- **Callbacks**: onSend, onTypingChanged
- **Lines**: ~95

## 📚 Documentation

### PRD.md
- **Purpose**: Product Requirements Document
- **Content**: MVP requirements, features, tech stack
- **Provided by**: User

### SETUP.md
- **Purpose**: Setup and configuration guide
- **Content**:
  - Firebase project creation
  - iOS app registration
  - SDK installation
  - Firestore setup
  - Security rules
  - Troubleshooting

### IMPLEMENTATION_SUMMARY.md
- **Purpose**: Overview of what was built
- **Content**:
  - Feature list
  - Architecture overview
  - Code statistics
  - Design philosophy

### APP_FLOW.md
- **Purpose**: Visual flow diagrams
- **Content**:
  - User flow diagrams
  - Screen hierarchy
  - Data flow
  - Message delivery flow

### FILE_REFERENCE.md (This File)
- **Purpose**: Quick file lookup
- **Content**: Description of every file and its purpose

## 📊 Code Statistics

| Category    | Files | Lines | Purpose                    |
|-------------|-------|-------|----------------------------|
| Models      | 3     | ~295  | Data structures            |
| Services    | 2     | ~450  | Business logic             |
| Views       | 3     | ~695  | Main screens               |
| Components  | 3     | ~320  | Reusable UI                |
| App         | 1     | ~65   | Entry point                |
| **Total**   | **12**| **~1825** | **Complete app**       |

## 🎯 Where to Look For...

### Authentication Logic
→ `Services/AuthService.swift`
→ `Views/LoginView.swift`

### Messaging Logic
→ `Services/MessageService.swift`
→ `Views/ChatView.swift`

### Data Models
→ `Models/User.swift`
→ `Models/Conversation.swift`
→ `Models/Message.swift`

### UI Components
→ `Components/AvatarView.swift`
→ `Components/MessageRow.swift`
→ `Components/MessageInputBar.swift`

### Real-time Listeners
→ `Services/MessageService.swift` (lines 30-80)

### Optimistic UI
→ `Services/MessageService.swift` → `sendMessage()` method

### Read Receipts
→ `Services/MessageService.swift` → `markMessagesAsRead()` method

### Typing Indicators
→ `Services/MessageService.swift` → `setTyping()` method
→ `Components/MessageInputBar.swift` → typing detection

### Online Status
→ `Services/AuthService.swift` → `updateOnlineStatus()` method
→ `Components/AvatarView.swift` → green dot indicator

### Navigation
→ `MessageAiApp.swift` → RootView (auth routing)
→ `Views/ConversationListView.swift` → NavigationLink to ChatView

## 🔍 Common Tasks

### Add a new message type (e.g., images)
1. Update `MessageType` enum in `Models/Message.swift`
2. Update `MessageRow.swift` to render image
3. Update `MessageInputBar.swift` to allow image selection
4. Update `MessageService.sendMessage()` to handle image upload

### Add push notifications
1. Add Firebase Cloud Messaging to packages
2. Request notification permissions
3. Handle device token registration
4. Listen for remote notifications
5. Add notification payload handling

### Add more user profile fields
1. Update `User` model in `Models/User.swift`
2. Update `UserDTO` for Firestore sync
3. Update `AuthService.updateUserProfile()`
4. Add UI in settings/profile screen

### Customize UI theme
1. Create `Theme.swift` with color constants
2. Replace hardcoded colors in views
3. Add theme toggle in settings
4. Persist theme preference

### Add message reactions
1. Add `reactions: [String: [String]]` to Message model
2. Add reaction picker UI in ChatView
3. Add `addReaction()` method to MessageService
4. Update Firestore schema

## 🚀 Quick Start Checklist

- [ ] Open `SETUP.md`
- [ ] Create Firebase project
- [ ] Add iOS app to Firebase
- [ ] Download `GoogleService-Info.plist`
- [ ] Add Firebase SDK packages
- [ ] Build project
- [ ] Run on simulator
- [ ] Create test accounts
- [ ] Send test messages
- [ ] Verify real-time updates

## 📞 Need Help?

- **Can't find where X is implemented?** → Use Xcode's `Cmd+Shift+F` to search
- **Build errors?** → Check `SETUP.md` troubleshooting section
- **Want to add a feature?** → Start in appropriate Service file
- **UI tweaks?** → Look in Views or Components folder
- **Data structure changes?** → Update Models + DTOs + Firestore
