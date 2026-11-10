# Apple Watch App — Xcode Setup

Bundle IDs:
- iPhone app : org.tanmaykumar.mmm
- Watch app  : org.tanmaykumar.mmm.watchkitapp

---

## Step 1 — Open project in Xcode

```
open ios/Runner.xcworkspace
```
Always open the `.xcworkspace`, not `.xcodeproj`.

---

## Step 2 — Add watchOS target

1. File → New → Target
2. Choose **watchOS → Watch App**
3. Set:
   - Product Name : `WatchApp`
   - Bundle ID    : `org.tanmaykumar.mmm.watchkitapp`
   - Team         : your Apple Developer account
   - Deployment   : watchOS 7.0+
4. Uncheck "Include Notification Scene" (not needed)
5. Click Finish → **Activate** the scheme when asked

---

## Step 3 — Add Swift source files

Delete the auto-generated ContentView.swift and WatchApp.swift Xcode created.

Drag all 5 files from `ios/WatchApp/` into the new WatchApp target in Xcode:
- WatchApp.swift
- ContentView.swift
- AddExpenseView.swift
- PhoneConnector.swift
- Models.swift

Make sure **Target Membership** = WatchApp (checkmark) for each file.

---

## Step 4 — Add WatchConnectivity framework

Select the **WatchApp** target → General tab → Frameworks, Libraries → **+**
→ Add `WatchConnectivity.framework`

---

## Step 5 — Enable WatchConnectivity on iPhone target (Runner)

Select the **Runner** target → Signing & Capabilities tab → **+ Capability**
→ Add **WatchConnectivity**

The `watch_connectivity` Flutter package adds this via CocoaPods automatically,
but confirm the capability appears in Runner's entitlements.

---

## Step 6 — Run flutter pub get

```
flutter pub get
```

This pulls in `watch_connectivity: ^1.0.1` which handles the iPhone WCSession side.

---

## Step 7 — Build & run

1. Select the **WatchApp** scheme in Xcode
2. Choose your paired Apple Watch simulator or device
3. Run — the watch app opens showing "Open MM on iPhone"
4. Run the iPhone app → watch receives card list automatically

---

## How it works

```
iPhone (Flutter)                    Apple Watch (SwiftUI)
─────────────────                   ──────────────────────
WatchService.init()      ──cards──▶  PhoneConnector
                         ◀─addTxn──  AddExpenseView.save()
sp.addCardTxn()  ◀──────────────────
```

- iPhone → Watch : `updateApplicationContext` with cards + people (persists even if watch is off)
- Watch → iPhone : `sendMessage` with new transaction (requires iPhone reachable / MM app open)
- iPhone receives message → `WatchService._handleMessage()` → `sp.addCardTxn()` → saved to Firebase
