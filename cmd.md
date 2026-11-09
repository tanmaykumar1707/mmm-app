# Build and install commands

Run these commands from the project root.

## iOS

Build an iOS release:

```bash
flutter build ios --release
```

Run the release build on the connected iPhone:

```bash
flutter run --release -d 00008101-000C184402A2001E
```

## Android

Run on the connected Android device (debug):

```bash
flutter run -d RZCY10STTHB
```

Build a debug APK:

```bash
flutter build apk --debug
```

Build a release APK:

```bash
flutter build apk --release
```

Install the release APK on a connected Android device:

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

If more than one Android device is connected, specify the device ID:

```bash
adb devices
adb -s RZCY10STTHB install build/app/outputs/flutter-apk/app-release.apk
```

For Google Play, build an Android App Bundle instead of an APK:

```bash
flutter build appbundle --release
```

The bundle is created at `build/app/outputs/bundle/release/app-release.aab`.
