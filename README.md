# SchoolComm

SchoolComm is a school and organization communication system built with Firebase and Flutter.

I originally started this project for my own school, but the timing and circumstances did not work out the way I had hoped, so I could not use it in a real school environment. I kept working on it and eventually decided to publish it as an open-source project.

The project is made of two Flutter applications: one for administrators and one for students. Firebase handles the backend, so there is no separate server to maintain.

## Apps

- admin_app — Admin side
- student_app — Student side
- packages/school_comm — Shared models, repositories, theme, and widgets
- functions — Backend logic for role management, student management, notifications, and cleanup tasks

More details about the architecture and the reasoning behind some design decisions can be found in `docs/ARCHITECTURE.md`.

## Main features

### Admin app

- Add and remove announcements
- Add and remove students
- Create and manage groups
- Send messages
- Send system notifications
- View a general dashboard

### Student app

- View announcements
- Manage group memberships
- Receive notifications
- View profile information
- Receive group messages

## Security

Security was an important part of this project.

Firestore and Storage rules are tested with the Firebase emulator. At the moment, the project includes 44 Firestore rule tests and 22 Storage rule tests. These tests cover both allowed access and denied access situations, so they are meant to reflect real misuse cases as well as normal usage.

The security tests are also run automatically in CI whenever changes are pushed to the repository.

### Role management

User roles are handled with Firebase custom claims and the matching Firestore user document.

Clients cannot directly change their own roles or access restricted data. If an account is disabled, the user also loses access to their protected data.

### Group membership

Group membership is stored under:

```
groups/{groupId}/members/{userId}
```

A `groupIds` list is also stored on the user's document. Both are updated in the same transaction so they stay in sync.

This also makes it easier for Firestore security rules to check if a user belongs to a group.

### Notifications

SchoolComm uses Firebase Cloud Messaging (FCM) for push notifications.

Notifications can be sent for:

- New announcements
- Group messages
- System notifications

Invalid device tokens are removed automatically, and old device registrations are cleaned up from time to time.

### Cost considerations

I tried to keep the project reasonably efficient and avoid unnecessary Firebase reads.

Examples:

- System-wide notifications use a single document instead of creating a document for every student.
- `count()` aggregations are used where possible instead of downloading documents just to count them.
- Real-time listeners are only active while the related screen is open.

## Architecture

The project is fairly straightforward:

- admin_app handles administrative tasks
- student_app is used by students
- Firestore stores application data
- Firebase Authentication handles user accounts
- Storage is used for file uploads and file-based content
- Cloud Functions handle operations that should not be done directly from the client
- FCM handles push notifications

The client does not directly perform sensitive write operations. Those are handled through Cloud Functions instead.

## Project structure

```text
school-comm/
├─ admin_app/             # Admin Flutter app
├─ student_app/           # Student Flutter app
├─ packages/school_comm/  # Shared models, repositories, theme and widgets
├─ functions/             # Firebase Cloud Functions
├─ tests/rules/           # Firestore and Storage security tests
├─ scripts/               # Utility scripts
├─ firestore.rules        # Firestore security rules
├─ storage.rules          # Storage security rules
├─ firestore.indexes.json
└─ .github/workflows/ci.yml
```

## Getting started

### Requirements

- Flutter SDK 3.35+ (stable)
- Node.js 20 or 22
- Java 17+ (required for the Firebase Emulator)
- A Firebase project
- Firebase Blaze plan for Cloud Functions and FCM

### 1. Clone the repository

```bash
git clone https://github.com/<username>/school-comm.git
cd school-comm
```

Install the Cloud Functions dependencies:

```bash
cd functions
npm install
cd ..
```

Install the dependencies used by the Firebase tests:

```bash
npm install
```

### 2. Connect Firebase

Log in to Firebase:

```bash
firebase login
firebase use --add
```

Then configure Firebase for both Flutter apps:

```bash
cd admin_app
flutterfire configure --project=<PROJECT_ID>

cd ../student_app
flutterfire configure --project=<PROJECT_ID>
```

The `firebase_options.dart` files are intentionally not included in the project. You should generate your own Firebase configuration for your Firebase project.

If the configuration is missing, the apps will show a message telling you that Firebase needs to be configured.

### 3. Create the first admin

First, create an account from the Admin app.

Then run:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=./service-account.json
node scripts/set-first-admin.mjs <PROJECT_ID> <ADMIN_EMAIL>
```

After the role is assigned, the user needs to log out and log back in so the new role is added to the authentication token.

## Optional environment variables

Some optional environment variables can be used with Cloud Functions:

- `ALLOWED_STUDENT_EMAIL_DOMAIN` — If set, only users with this email domain can register.
- `BOOTSTRAP_FIRST_USER_AS_ADMIN` — If set to `true`, the first registered user becomes an admin. This should only be used in development.

## Testing

To run the full verification process:

```bash
npm run build:all
```

This checks the Cloud Functions, Firestore rules, Storage rules, and Flutter packages.

You can also run the tests separately:

```bash
npm run test:rules
npm run test:storage
(cd packages/school_comm && flutter test)
```

Current test counts:

- 44 Firestore rule tests
- 22 Storage rule tests
- 21 Dart unit tests

## Running locally

Start the Firebase emulators:

```bash
npm run emulators
```

The Emulator UI will be available at:

```text
http://localhost:4000
```

Then run either app:

```bash
cd admin_app
flutter run
```

or:

```bash
cd student_app
flutter run
```

Default emulator ports:

| Service | Port |
|---------|------|
| Firestore | 8080 |
| Authentication | 9099 |
| Storage | 9199 |
| Functions | 5001 |
| Emulator UI | 4000 |

## Build and deploy

To deploy the Firebase backend:

```bash
npm run deploy
```

To deploy only the security rules:

```bash
firebase deploy --only firestore:rules,storage
```

Build the Android apps with:

```bash
cd admin_app
flutter build apk --release
flutter build appbundle --release
```

And for the student app:

```bash
cd ../student_app
flutter build apk --release
```

## Known limitations

There are a few things to keep in mind when using the project.

### Storage rules

Some file size and content-type checks cannot be fully tested with the Firebase Storage Emulator because of limitations in the emulator test environment.

Access permissions are tested, but those checks should still be tested in a real Firebase project before production use.

### Storage permissions and token lifetime

Storage rules use authentication claims to check some permissions. Because of that, changes to group membership may take a bit of time to reach the user's authentication token.

Firestore access, however, is updated immediately.

### Scheduled announcements

Announcements with a future date do not currently trigger a notification at the exact time. A scheduled Cloud Function would be needed for automatic publishing at a specific time.

### Search

Search currently uses field filtering and client-side matching.

For a large number of students, a dedicated search service such as Algolia or Typesense would be a better option, or adding a searchable keyword field to the data model would help.

## CI

The GitHub Actions workflow runs automatically on every push.

It currently checks:

- Cloud Functions type checking
- Firestore security rules
- Storage security rules
- Flutter analysis
- Flutter tests

That helps catch regressions before they make it into the codebase.

## License

This project is licensed under the MIT License.

See the `LICENSE` file for more information.
