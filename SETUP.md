# My Money Manager (MMM) — Firebase Setup Guide

## 1. Create a Firebase Project

1. Go to https://console.firebase.google.com/
2. Click **Add project** → name it (e.g. `my-money-manager`)
3. Disable Google Analytics if you want (optional)
4. Click **Create project**

---

## 2. Add Android App to Firebase

1. In your Firebase project, click the **Android** icon to add an Android app
2. Enter package name: `org.tanmaykumar.mmm`
3. Enter app nickname: `MMM` (optional)
4. Click **Register app**
5. Download **google-services.json**
6. Place it at: `android/app/google-services.json`
7. Click **Next** through the remaining steps (the Gradle files are already configured)

---

## 3. Enable Google Sign-In

1. In Firebase Console → **Authentication** → **Sign-in method**
2. Click **Google** → Enable it → Save
3. Add your SHA-1 fingerprint (get it with):
   ```
   cd android
   ./gradlew signingReport
   ```
   Copy the SHA-1 from the `debug` variant and add it in Firebase Console → Project Settings → Your Android app

---

## 4. Enable Realtime Database

1. In Firebase Console → **Realtime Database** → **Create database**
2. Choose a region (e.g. `asia-south1` for India)
3. Start in **Test mode** (you'll add security rules next)
4. Copy your database URL (looks like `https://YOUR_PROJECT_ID-default-rtdb.asia-south1.firebasedatabase.app`)

### Security Rules
In Firebase Console → Realtime Database → **Rules**, paste:

```json
{
  "rules": {
    "userData": {
      "$uid": {
        ".read": "auth != null && (auth.uid === $uid || root.child('shares/' + $uid + '/grantedTo/' + auth.uid).exists())",
        ".write": "auth != null && auth.uid === $uid"
      }
    },
    "profiles": {
      ".read": "auth != null",
      "$uid": {
        ".write": "auth != null && auth.uid === $uid"
      }
    },
    "shares": {
      "$uid": {
        ".read": "auth != null && auth.uid === $uid",
        ".write": "auth != null && auth.uid === $uid"
      }
    },
    "receivedAccess": {
      "$targetUid": {
        ".read": "auth != null && auth.uid === $targetUid",
        "$ownerUid": {
          ".write": "auth != null && auth.uid === $ownerUid && (!newData.exists() || root.child('shares/' + $ownerUid + '/grantedTo/' + $targetUid).exists())"
        }
      }
    }
  }
}
```

---

## 5. Update FirebaseOptions in main.dart

Open `lib/main.dart` and replace the placeholder `firebaseOptions` with your actual values from Firebase Console → Project Settings → Your apps → SDK setup:

```dart
const firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSy...',          // From Firebase Console
  appId: '1:123456789:android:abc123',
  messagingSenderId: '123456789',
  projectId: 'your-project-id',
  databaseURL: 'https://your-project-id-default-rtdb.asia-south1.firebasedatabase.app',
  storageBucket: 'your-project-id.appspot.com',
);
```

**Tip:** Instead of copying manually, install `flutterfire_cli` and run:
```
dart pub global activate flutterfire_cli
flutterfire configure
```
This auto-generates `lib/firebase_options.dart` with all values filled in, then update `main.dart` to use `DefaultFirebaseOptions.currentPlatform`.

---

## 6. Fonts (Outfit)

The app uses the Outfit font. Download from https://fonts.google.com/specimen/Outfit and place these files in `assets/fonts/`:

- `Outfit-Regular.ttf`
- `Outfit-Medium.ttf`
- `Outfit-SemiBold.ttf`
- `Outfit-Bold.ttf`

If you skip the fonts, remove the `fonts:` section from `pubspec.yaml` and the `fontFamily: 'Outfit'` references in `lib/widgets/app_theme.dart`.

---

## 7. Windows Developer Mode (for plugin builds)

Flutter on Windows needs Developer Mode enabled to create symlinks for plugins:

1. Run: `start ms-settings:developers`
2. Enable **Developer Mode**
3. Restart your terminal

---

## 8. Run the App

```powershell
# Connect an Android device or start an emulator, then:
& "C:\Users\tanmkumar\flutterdevelop\flutter\bin\flutter.bat" run
```

For a release APK:
```powershell
& "C:\Users\tanmkumar\flutterdevelop\flutter\bin\flutter.bat" build apk --release
# APK will be at: build\app\outputs\flutter-apk\app-release.apk
```

---

## App Features

- **This Month tab**: Track monthly expenses, mark paid/pending, copy from defaults
- **Cards tab**: Credit card transactions split into This Bill / Next Bill, Cash/Wallet payments
- **LB tab**: Lent & Borrowed money tracking with repayment history
- **Defaults tab**: Recurring monthly expense templates, people management
- **Workspace sharing**: Share read-only access to your data with another MMM user
- **Google Sign-In**: Secure auth, data synced to Firebase Realtime Database
