
# BoardBuddy — Collaborative Team Task Management

BoardBuddy is a collaborative mobile task management application built with Flutter and Firebase. It provides a Kanban-style workspace where users can organize tasks, collaborate with team members, track progress, and manage project deadlines in real time.

The application combines an intuitive task management interface with secure authentication, cloud-based data storage, real-time synchronization, and structured state management using Provider.

---

## Project Information

| Information | Details |
|---|---|
| Project Name | BoardBuddy |
| Project Topic | P06 — Team Task Board |
| Developer | Akhi Ketu Chakma |
| Student ID | 2210952 |
| University | Independent University, Bangladesh |
| Platform | Flutter Mobile Application |
| Backend | Firebase |
| State Management | Provider |
| Development Status | Core Functionality Implemented |

---

## Features

### Authentication

- User registration with name, email, and password.
- Secure login using Firebase Authentication.
- Email verification.
- Authentication-based navigation.
- Secure logout.
- Persistent authentication sessions.

### Board Management

- Create boards with customizable titles and colors.
- View owned and joined boards.
- Edit board information.
- Display open task counts.
- Delete boards with confirmation.
- Remove related cards, columns, comments, activities, and invitations during board deletion.
- Real-time board synchronization.

### Team Collaboration

- Invite registered and verified users using their email addresses.
- Receive, accept, or decline board invitations.
- Prevent self-invitations.
- Prevent duplicate pending invitations.
- Prevent invitations to existing board members.
- Reject email addresses that are not registered in the verified-user directory.
- View current board members and their roles.
- Remove members as a board owner.
- Leave shared boards as a regular member.
- Clean up task assignments when members leave or are removed.

### Kanban Board

- Horizontally arranged task columns.
- Vertically arranged task cards.
- Create, rename, and reorder columns.
- Delete empty columns.
- Prevent deletion of non-empty columns through the application.
- Drag and drop tasks within and across columns.
- Persist task positions in Firestore.
- Real-time updates across collaborating devices.
- Filter tasks by assigned member, label, and upcoming due date.

### Task Management

Each task supports:

- Task title and description.
- Multiple assigned members.
- Colored labels.
- Due dates.
- Interactive checklists.
- Checklist completion progress.
- Real-time comments.
- Activity history.
- Task completion and reopening.
- Task archiving and restoration.
- Permanent deletion by the board owner.

### Comments and Activity History

- Post and view task comments in real time.
- Display comment author names and timestamps.
- Record task-related activities.
- Track task creation, updates, movement, completion, and archiving.
- Preserve historical author and actor names in newly created records.
- Maintain compatibility with older comment and activity documents.

### My Tasks

A dedicated My Tasks screen displays active tasks assigned to the current user across accessible boards.

Tasks are organized into:

- Overdue
- Today
- This Week
- Later

Assigned tasks are retrieved using Firestore collection-group queries and updated in real time.

### User Profile

- Display the authenticated user's name.
- Display the registered email address.
- Display accessible board count.
- Display active assigned task count.
- Display completed task count.
- Logout with confirmation.

---

## Technology Stack

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform application development |
| Dart | Application programming language |
| Firebase Authentication | Account registration and authentication |
| Cloud Firestore | Cloud database and real-time synchronization |
| Provider | Reactive state management |
| Material Design | Application interface and components |
| Git | Version control |
| GitHub | Source code repository |

---

## Application Architecture

BoardBuddy follows a layered architecture that separates the user interface, state management, business logic, data models, and database operations.

```text
User Interface
      |
      v
Provider State Management
      |
      v
Service Layer
      |
      v
Firebase Authentication / Cloud Firestore
```

### State Management

The application uses five primary providers.

| Provider | Responsibility |
|---|---|
| AuthProvider | Authentication and account state |
| BoardProvider | Board management, invitations, and membership operations |
| ColumnProvider | Column management and ordering |
| CardProvider | Task management, assignments, comments, activity, and card movement |
| MyTasksProvider | Cross-board assigned task queries and due-date grouping |

The Provider architecture helps maintain reactive interfaces while separating application state from database operations.

### Service Layer

The service layer handles Firebase communication and application operations, including:

- User profile management.
- Board creation and updates.
- Column management.
- Task creation and updates.
- Invitation validation.
- Board membership management.
- Comment and activity management.
- Task, column, and board deletion.

---

## Project Structure

```text
boardbuddy/
│
├── android/
├── ios/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── firebase_options.dart
│   │
│   ├── core/
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   └── widgets/
│   │       ├── board_title.dart
│   │       ├── kanban_column_widget.dart
│   │       └── task_card_widget.dart
│   │
│   ├── models/
│   │   ├── board.dart
│   │   ├── board_column.dart
│   │   ├── task_card.dart
│   │   └── task_interaction.dart
│   │
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── board_provider.dart
│   │   ├── column_provider.dart
│   │   ├── card_provider.dart
│   │   └── my_task_provider.dart
│   │
│   ├── services/
│   │   ├── user_profile_service.dart
│   │   ├── board_service.dart
│   │   ├── column_service.dart
│   │   ├── card_service.dart
│   │   ├── task_interaction_service.dart
│   │   ├── board_invitation_service.dart
│   │   ├── board_member_service.dart
│   │   ├── task_deletion_service.dart
│   │   ├── column_deletion_service.dart
│   │   └── board_deletion_service.dart
│   │
│   └── screens/
│       ├── auth/
│       ├── boards/
│       ├── home/
│       ├── tasks/
│       └── profile/
│
├── test/
├── pubspec.yaml
├── .gitignore
└── README.md
```

---

## Firestore Database Design

BoardBuddy uses a hierarchical Cloud Firestore data model.

```text
Firestore
│
├── users/
│   └── {userId}
│
├── emailDirectory/
│   └── {normalizedEmail}
│
└── boards/
    └── {boardId}
        │
        ├── invitations/
        │   └── {email}
        │
        ├── columns/
        │   └── {columnId}
        │
        └── cards/
            └── {cardId}
                │
                ├── comments/
                │   └── {commentId}
                │
                └── activity/
                    └── {activityId}
```

### User Document

| Field | Type |
|---|---|
| name | String |
| email | String |
| createdAt | Timestamp |

### Email Directory Document

| Field | Type |
|---|---|
| uid | String |

The normalized verified email address is used as the document ID. The directory supports exact-email lookup without allowing clients to list all registered accounts.

### Board Document

| Field | Type |
|---|---|
| title | String |
| colorHex | String |
| ownerId | String |
| memberIds | Array |
| memberNames | Map |
| createdAt | Timestamp |

### Column Document

| Field | Type |
|---|---|
| title | String |
| position | Number |
| createdAt | Timestamp |

### Task Card Document

| Field | Type |
|---|---|
| boardId | String |
| columnId | String |
| title | String |
| description | String |
| position | Number |
| assigneeIds | Array |
| labels | Array |
| dueDate | Timestamp / Null |
| checklist | Array |
| completed | Boolean |
| archived | Boolean |
| createdBy | String |
| createdAt | Timestamp |

### Checklist Item

| Field | Type |
|---|---|
| id | String |
| text | String |
| done | Boolean |

### Label

| Field | Type |
|---|---|
| name | String |
| colorHex | String |

### Invitation Document

| Field | Type |
|---|---|
| boardId | String |
| boardTitle | String |
| email | String |
| invitedBy | String |
| createdAt | Timestamp |

### Comment Document

| Field | Type |
|---|---|
| authorId | String |
| authorName | String |
| text | String |
| createdAt | Timestamp |

### Activity Document

| Field | Type |
|---|---|
| actorId | String |
| actorName | String |
| action | String |
| message | String |
| createdAt | Timestamp |

---

## Task Ordering Algorithm

BoardBuddy uses numeric position values to manage task ordering.

When a task is moved between two existing cards, its new position can be calculated using the midpoint:

```text
newPosition = (previousPosition + nextPosition) / 2
```

Example:

```text
Task A: 1000
Task B: 2000

Insert Task C between A and B:

Task C position = (1000 + 2000) / 2
                = 1500
```

The resulting order is:

```text
Task A → 1000
Task C → 1500
Task B → 2000
```

This approach allows a normal drag-and-drop operation to update a single card document. Activity history is recorded separately.

When position gaps become too small, positions are rebalanced to maintain consistent ordering.

Creation timestamps and document IDs are used as secondary ordering criteria when position values are equal.

---

## Real-Time Synchronization

Cloud Firestore snapshot listeners synchronize application data across collaborating users.

Real-time synchronization is used for:

- Board lists.
- Board membership.
- Kanban columns.
- Task cards.
- Task assignments.
- Comments.
- Activity history.
- Incoming invitations.
- My Tasks.

Changes made by one authorized user become available to other authorized users through Firestore streams.

---

## Firestore Indexes

The My Tasks feature uses a collection-group query on the cards collection.

```dart
FirebaseFirestore.instance
    .collectionGroup('cards')
    .where('boardId', isEqualTo: boardId)
    .where('assigneeIds', arrayContains: userId);
```

Required composite index:

| Collection ID | Field | Index Mode |
|---|---|---|
| cards | boardId | Ascending |
| cards | assigneeIds | Arrays |

Query scope: Collection group.

The invitation inbox also requires a collection-group index:

| Collection ID | Field | Index Mode |
|---|---|---|
| invitations | email | Ascending |

Query scope: Collection group.

---

## Security and Access Control

BoardBuddy uses Firebase Authentication and Cloud Firestore Security Rules to control access to application data.

The implemented access controls include:

- Authenticated access to application resources.
- Private user profile documents.
- Board access restricted to current members.
- Owner-only board editing and permanent deletion.
- Owner-only invitation creation.
- Verified-email invitation acceptance.
- Registered recipient validation.
- Duplicate invitation prevention.
- Owner-only member removal.
- Regular member access to leave shared boards.
- Validation of new task assignments against board membership.
- Validation of comment and activity author identities.
- Restricted collection-group queries.
- Denial of unauthorized database operations.

The email directory supports exact-email lookup by authenticated users. Directory listing is disabled, although individual email lookups remain possible.

---

## Getting Started

### Prerequisites

Install the following development tools:

- Flutter SDK
- Dart SDK
- Git
- Android Studio or Visual Studio Code
- Android Emulator or a physical Android device
- Firebase project
- FlutterFire CLI

### 1. Clone the Repository

```bash
git clone https://github.com/AkhiKetu/boardbuddy.git
cd boardbuddy
```

Repository access is required if the repository is private.

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

Create or select a Firebase project.

Enable the following services:

- Firebase Authentication
- Email/Password sign-in provider
- Cloud Firestore

Install FlutterFire CLI if required:

```bash
dart pub global activate flutterfire_cli
```

Configure the Flutter application:

```bash
flutterfire configure
```

Apply the appropriate Cloud Firestore Security Rules and create the required indexes described above.

When using an independent Firebase project, update the generated Firebase configuration to match that project.

### 4. Check the Development Environment

```bash
flutter doctor
```

### 5. Run the Application

Connect a physical device or start an Android emulator.

```bash
flutter run
```

### 6. Build an Android APK

```bash
flutter build apk --release
```

The release APK is generated at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## Application Usage

1. Register or log in using an existing account.
2. Create a new board and select a board color.
3. Create or organize Kanban columns.
4. Add tasks to the board.
5. Open task details to manage assignments, labels, due dates, and checklists.
6. Invite registered and verified team members.
7. Accept incoming invitations from Board Invitations.
8. Collaborate using comments and activity history.
9. Move tasks between columns as work progresses.
10. Track assigned work from the My Tasks screen.
11. View account and task statistics in Profile.

For invitation discovery, verified users currently need to open the Board Invitations screen at least once to register their email in the application directory.

---

## Testing and Validation

The following development checks have been executed successfully:

```bash
dart format lib
flutter analyze
flutter test
```

Results:

| Check | Result |
|---|---|
| Dart source formatting | Passed |
| Flutter static analysis | No issues found |
| Automated Flutter tests | Passed |

Manual application testing has also been performed during development to verify core functionality, including authentication, board management, collaboration, task management, and assigned-task tracking.

Further regression testing is recommended before final submission or production deployment.

---

## Current Development Status

The core application functionality has been implemented, including:

- Firebase authentication and database integration.
- Collaborative board management.
- User invitations and membership management.
- Kanban task management.
- Persistent drag-and-drop ordering.
- Task assignments and due dates.
- Checklist management.
- Comments and activity history.
- My Tasks collection-group queries.
- Profile statistics.
- Firestore access control.

The current version establishes the functional foundation of BoardBuddy.

Future development will primarily focus on interface refinement, usability improvements, and additional testing.

---

## Known Limitations

- Verified users currently need to open Board Invitations once before becoming discoverable through the email directory.
- Invitations are delivered through the application's invitation inbox rather than external email messages.
- The email directory does not automatically detect accounts deleted directly through Firebase Authentication.
- Activity history is recorded separately from task updates and is not a transactional audit log.
- Older cards created before the collection-group implementation may require their boardId field to be populated.
- The application is primarily developed and tested for Android.
- Additional testing is required for large boards and concurrent editing scenarios.

---

## Future Improvements

- Improved visual design and application consistency.
- Enhanced animations and transitions.
- Improved mobile responsiveness.
- Automatic registration of verified users in the email directory.
- Additional automated and integration tests.
- Performance optimization for large Kanban boards.
- Improved accessibility and empty-state designs.
- Optional task reminders and notifications.
- Further collaboration and project management enhancements.

---

## Developer

**Akhi Ketu Chakma**

Student ID: 2210952

Independent University, Bangladesh

GitHub: [AkhiKetu](https://github.com/AkhiKetu)

---

## Acknowledgements

- Flutter development framework
- Firebase Authentication and Cloud Firestore
- Provider state management
- Material Design
- Independent University, Bangladesh

---

BoardBuddy was developed as an academic mobile application project demonstrating collaborative task management, real-time cloud synchronization, secure authentication, and structured Flutter application development.
