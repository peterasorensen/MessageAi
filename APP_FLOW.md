# MessageAi App Flow

## 🔄 User Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        App Launch                            │
│                    MessageAiApp.swift                        │
│                  FirebaseApp.configure()                     │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
                  ┌──────────┐
                  │ RootView │
                  └─────┬────┘
                        │
           ┌────────────┴────────────┐
           │                         │
      Not Authenticated         Authenticated
           │                         │
           ▼                         ▼
    ┌─────────────┐          ┌──────────────────┐
    │  LoginView  │          │ ConversationList │
    └──────┬──────┘          └────────┬─────────┘
           │                          │
    ┌──────┴──────┐                  │
    │             │                  │
Sign Up      Sign In                 │
    │             │                  │
    └──────┬──────┘                  │
           │                         │
           ▼                         ▼
    ┌─────────────┐          ┌──────────────────┐
    │ AuthService │          │  MessageService  │
    │  Firebase   │          │    Firestore     │
    │    Auth     │          │    Listeners     │
    └─────────────┘          └────────┬─────────┘
                                      │
                        ┌─────────────┴─────────────┐
                        │                           │
                   New Chat                    Select Chat
                        │                           │
                        ▼                           ▼
                 ┌─────────────┐            ┌─────────────┐
                 │ NewChatView │            │  ChatView   │
                 │ User List   │            │  Messages   │
                 └──────┬──────┘            └──────┬──────┘
                        │                           │
                        └────────────┬──────────────┘
                                     │
                                     ▼
                              ┌─────────────┐
                              │   Send      │
                              │  Message    │
                              └─────────────┘
```

## 📱 Screen Hierarchy

```
MessageAiApp (Root)
│
├── RootView (Auth Router)
│   │
│   ├── LoginView (Not Authenticated)
│   │   ├── Email/Password Fields
│   │   ├── Sign Up / Sign In Toggle
│   │   └── Submit Button
│   │
│   └── ConversationListView (Authenticated)
│       ├── Header
│       │   ├── User Avatar (Menu)
│       │   └── New Chat Button
│       │
│       ├── Search Bar
│       │
│       ├── Conversation List
│       │   └── ConversationRow (repeating)
│       │       ├── AvatarView
│       │       ├── Name & Timestamp
│       │       ├── Last Message
│       │       ├── Unread Badge
│       │       └── Typing Indicator
│       │
│       └── NewChatView (Sheet)
│           └── User List
│               └── User Row (repeating)
│                   ├── AvatarView
│                   └── Name & Status
│
└── ChatView (Navigation Destination)
    ├── Navigation Bar
    │   └── Conversation Name
    │
    ├── Messages ScrollView
    │   ├── MessageRow (repeating)
    │   │   ├── Message Bubble
    │   │   ├── Timestamp
    │   │   └── Status Indicator
    │   │
    │   └── Typing Indicator
    │
    └── MessageInputBar
        ├── Text Field
        └── Send Button
```

## 🔥 Firebase Data Flow

```
┌──────────────────────────────────────────────────────────────┐
│                         USER ACTIONS                          │
└───────────────────────┬──────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
   ┌────────┐    ┌──────────┐    ┌──────────┐
   │ Sign Up│    │Send Msg  │    │Read Msgs │
   └───┬────┘    └────┬─────┘    └────┬─────┘
       │              │               │
       ▼              ▼               ▼
┌─────────────────────────────────────────────┐
│           OPTIMISTIC UI UPDATE               │
│        (Instant Local Feedback)              │
└───────────────────┬─────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│              FIREBASE SERVICES               │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐ │
│  │   Auth   │  │Firestore │  │ SwiftData │ │
│  └────┬─────┘  └────┬─────┘  └─────┬─────┘ │
└───────┼─────────────┼──────────────┼────────┘
        │             │              │
        ▼             ▼              ▼
┌─────────────────────────────────────────────┐
│            REAL-TIME LISTENERS               │
│    (Automatic UI Updates on Changes)        │
└───────────────────┬─────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│              UI AUTO-UPDATES                 │
│         (SwiftUI Reactive Binding)           │
└─────────────────────────────────────────────┘
```

## 🎯 Message Send Flow

```
User Types Message
       │
       ▼
MessageInputBar.onSend()
       │
       ▼
Create Optimistic Message
       │
       ├──────────────────────────┐
       │                          │
       ▼                          ▼
Show in UI Immediately    Send to Firestore
   (Sending Status)              │
       │                         │
       │                    ┌────┴────┐
       │                    │         │
       │                Success    Failed
       │                    │         │
       │                    ▼         ▼
       │           Update Status  Show Error
       │                    │
       │                    ▼
       │           Firestore Listener
       │                    │
       │                    ▼
       └────────►  Remove Optimistic
                          │
                          ▼
                   Show Real Message
                  (Sent/Delivered)
```

## 💬 Real-time Message Delivery

```
User A                    Firestore                   User B
  │                          │                          │
  │  Send Message            │                          │
  ├─────────────────────────►│                          │
  │                          │                          │
  │  Optimistic UI           │   Listener Triggered     │
  │  (instant)               ├─────────────────────────►│
  │                          │                          │
  │                          │   Message Appears        │
  │                          │   (instant)              │
  │                          │                          │
  │  Listener Update         │                          │
  │◄─────────────────────────┤                          │
  │                          │                          │
  │  Mark as Delivered       │                          │
  │                          │                          │
  │                          │   User B Opens Chat      │
  │                          │◄─────────────────────────┤
  │                          │                          │
  │                          │   Mark as Read           │
  │                          │◄─────────────────────────┤
  │                          │                          │
  │  Read Receipt            │                          │
  │◄─────────────────────────┤                          │
  │                          │                          │
  │  Update UI               │                          │
  │  (blue checkmarks)       │                          │
  │                          │                          │
```

## 🔐 Authentication Flow

```
User Opens App
      │
      ▼
Firebase Auth Check
      │
  ┌───┴───┐
  │       │
Has Token  No Token
  │       │
  ▼       ▼
Auto    Show
Login   LoginView
  │       │
  │   ┌───┴───┐
  │   │       │
  │ Sign Up Sign In
  │   │       │
  │   └───┬───┘
  │       │
  │       ▼
  │   Create/Validate
  │   Credentials
  │       │
  │   ┌───┴───┐
  │   │       │
  │ Success  Error
  │   │       │
  └───┤       ▼
      │   Show Error
      ▼   Message
 Create/Load
 User Profile
      │
      ▼
 Update Online
    Status
      │
      ▼
Start Listeners
      │
      ▼
Show ConversationList
```

## 📊 State Management

```
┌─────────────────────────────────────────┐
│           @Observable Services           │
├─────────────────────────────────────────┤
│  AuthService                             │
│  ├── currentUser: User?                  │
│  ├── isAuthenticated: Bool               │
│  └── authError: String?                  │
│                                          │
│  MessageService                          │
│  ├── conversations: [Conversation]       │
│  ├── messages: [String: [Message]]       │
│  └── activeConversationId: String?       │
└───────────────┬─────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────┐
│          SwiftUI Auto-Updates            │
│      (Views Observe State Changes)      │
└─────────────────────────────────────────┘
```

## 🎨 Component Reusability

```
AvatarView
├── Used in ConversationRow
├── Used in NewChatView
├── Used in ChatView Header
└── Used in User Menu

MessageRow
└── Used in ChatView

MessageInputBar
└── Used in ChatView

ConversationRow
└── Used in ConversationListView
```

## 🚀 Performance Optimizations

1. **Optimistic UI** - Instant feedback before server
2. **Local Caching** - SwiftData for offline access
3. **Lazy Loading** - Lists only render visible items
4. **Efficient Queries** - Firestore indexed queries
5. **Smart Listeners** - Only active conversations
6. **Debounced Typing** - Reduce Firestore writes
7. **Computed Properties** - Minimize re-renders

## 🎯 Next User Action Examples

### Start New Conversation
```
ConversationList → + Button → NewChatView →
Select User → ChatView → Type & Send
```

### Reply to Message
```
ConversationList → Tap Row → ChatView →
Type in Input Bar → Send Button → Message Sent
```

### Check Online Status
```
ConversationList → NewChatView →
See Green Dot = Online
```

### See Read Receipt
```
ChatView → Send Message →
Clock → Checkmark → Double Check → Blue Double Check
```
