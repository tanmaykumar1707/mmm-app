# My Money Manager (MMM)

Personal finance tracker — Flutter app with Firebase sync, workspace sharing, and multi-platform support.

## Setup after cloning

### 1. Firebase credentials (required)

These files are gitignored and must be created manually:

```
cp lib/firebase_options.dart.template lib/firebase_options.dart
# Edit firebase_options.dart and fill in your Firebase project credentials
# Get them from: Firebase Console → Project Settings → Your apps
```

Also place platform-specific files:
- **Android**: `android/app/google-services.json` (download from Firebase Console → Android app)
- **iOS**: `ios/Runner/GoogleService-Info.plist` (download from Firebase Console → iOS app)

### 2. Install dependencies

```
flutter pub get
```

### 3. Run

```
# Web (profile mode recommended)
flutter run -d chrome --web-port=5173 --profile

# Android
flutter run -d <device-id>
```

## Package name

`org.tanmaykumar.mmm`

## Firebase project

`my-mm-tanmay` — Realtime Database + Auth (Google Sign-In)
