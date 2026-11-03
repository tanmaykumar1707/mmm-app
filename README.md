# My Money Manager (MMM)

Personal finance tracker — Flutter app with Firebase sync, workspace sharing, and multi-platform support.

---

## Setup after cloning

### 1. Firebase credentials (required)

These files are gitignored and must be created manually:

```
cp lib/firebase_options.dart.template lib/firebase_options.dart
# Edit firebase_options.dart and fill in your Firebase project credentials
# Get them from: Firebase Console → Project Settings → Your apps
```

Also place platform-specific files:
- **Android**: `android/app/google-services.json` (Firebase Console → Android app → download config)
- **iOS**: `ios/Runner/GoogleService-Info.plist` (Firebase Console → iOS app → download config)

### 2. Install dependencies

```
flutter pub get
```

---

## Running the app

### Web
```
flutter run -d chrome --web-port=5173 --profile
```

### Android (debug)
```
flutter run -d <device-id>
```

### iOS (debug — Mac + Xcode required)
```
# 1. Install CocoaPods dependencies (first time only)
cd ios && pod install && cd ..

# 2. Connect iPhone via USB, trust the computer on the phone

# 3. List available devices
flutter devices

# 4. Run on iPhone
flutter run -d <iphone-device-id>
```
If Xcode shows a signing error: open `ios/Runner.xcworkspace` in Xcode →
Signing & Capabilities → select your Apple Developer Team → re-run.

---

## Release builds

### Android release

**Step 1 — Generate signing keystore (one time only, keep this file safe)**
```
keytool -genkey -v -keystore mmm-release.jks -keyAlias mmm -keyalg RSA -keysize 2048 -validity 10000
```
Save `mmm-release.jks` somewhere safe (NOT inside the project folder — do not commit it).

**Step 2 — Create `android/key.properties`** (gitignored, create manually)
```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=mmm
storeFile=C:/full/path/to/mmm-release.jks
```

**Step 3 — Add signing config to `android/app/build.gradle.kts`**

At the top, before `android {`:
```kotlin
import java.util.Properties
val keyProps = Properties().apply {
    rootProject.file("key.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}
```

Inside `android { ... }`:
```kotlin
signingConfigs {
    create("release") {
        keyAlias     = keyProps["keyAlias"] as String?
        keyPassword  = keyProps["keyPassword"] as String?
        storeFile    = keyProps["storeFile"]?.let { file(it) }
        storePassword= keyProps["storePassword"] as String?
    }
}
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = false
    }
}
```

**Step 4 — Build**
```
# APK (direct install / testing)
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# App Bundle (Play Store upload)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

Install APK directly on any Android device:
```
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

### iOS release / install on iPhone without App Store

With an Apple Developer account you have three options — no App Store needed:

#### Option A — Run directly via Xcode (easiest for your own iPhone)
```
# Connect iPhone via USB
flutter build ios --release
open ios/Runner.xcworkspace
```
In Xcode: Product → Run (or ⌘R). The app installs on your phone.
On the iPhone: Settings → General → VPN & Device Management → trust your developer certificate.

#### Option B — Ad Hoc IPA (share with up to 100 devices)
```
flutter build ipa --release
# Output: build/ios/ipa/mmm.ipa
```
1. In Xcode → Product → Archive (if flutter build ipa doesn't work directly)
2. Window → Organizer → Distribute App → Ad Hoc
3. Register your iPhone's UDID in Apple Developer Portal first
4. Install the IPA via **Apple Configurator 2** (free, Mac App Store) or drag to Finder → iPhone

Get your iPhone's UDID: connect to Mac → open Finder → click iPhone → click the model line until UDID shows.

#### Option C — TestFlight (easiest for sharing with others)
```
flutter build ipa --release
```
1. Upload IPA to App Store Connect (via Xcode Organizer or Transporter app)
2. App Store Connect → TestFlight → Internal Testing → add your Apple ID
3. Install TestFlight on iPhone → accept the invite → install the app

TestFlight builds expire after 90 days. No App Store review needed for internal testers.

---

## Package name

`org.tanmaykumar.mmm`

## Firebase project

`my-mm-tanmay` — Realtime Database + Auth (Google Sign-In)
