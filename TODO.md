# MMM App TODO

Last reviewed: **2 November 2026**

Legend: ✅ Done · ⏭ Unnecessary · 👤 You need to do · 🔧 Still needed

---

## Dependencies

- ✅ **Removed unused packages** — `shared_preferences` and `uuid` were declared but never imported; removed from `pubspec.yaml`
- ✅ **Fixed `withOpacity` deprecations** — replaced all `.withOpacity()` calls with `.withValues(alpha:)` across all 8 files
- ⏭ **Major Firebase upgrade (Core 4.x / Auth 7.x / Database 13.x)** — current locked versions work fine; major upgrades carry breaking changes and need dedicated testing. Skip until a breakage forces it.
- ⏭ **Raise minimum Dart SDK** — current `>=3.0.0` works; no reason to tighten it now
- ⏭ **Update flutter_lints to 6.x** — cosmetic tooling change; low priority
- ⏭ **google_sign_in v7 migration** — v6 works on Android; web already uses Firebase Auth directly (bypasses google_sign_in). No migration needed until v6 is removed.
- ⏭ **Dependency audit / lock-file ceremony** — no known vulnerabilities in current set

---

## Auth & lifecycle

- ✅ **Auth stream subscription now cancelled on dispose** — `_authSub` stored and cancelled in `_AuthGateState.dispose()`
- ✅ **Loading/error/offline experience** — dark blue loading screen, 10-second timeout, Firebase error shown on screen with Retry
- ✅ **Google Sign-In on web** — uses `signInWithPopup` via Firebase Auth directly (bypasses deprecated `google_sign_in.signIn()`)
- ✅ **revokeAccess order fixed** — `receivedAccess` removed before `shares/grantedTo` to satisfy security rules

---

## Performance & data safety

- ✅ **Debounced Firebase writes** — `save()` now waits 600 ms after the last mutation before writing; rapid taps no longer each trigger a full state upload
- ✅ **State subscription cancelled on workspace switch and sign-out**
- 🔧 **Offline / conflict handling** — no local cache; if Firebase is unreachable the app shows stale data with no indicator. Add `keepSynced(true)` on the database ref for basic offline support.
- 🔧 **Serial profile fetches in `getSharedWorkspaces`** — one round-trip per shared owner; acceptable for ≤5 shares, but denormalize display names into `receivedAccess` nodes if you expect more.
- 🔧 **Confirm before destructive actions** — `deleteExpense`, `deleteCard`, `clearAll`, `createMonthFromDefaults` (overwrites existing month) all execute immediately with no confirmation dialog.

---

## iOS

- 👤 **Build and smoke-test on real iPhone** — connect Mac wirelessly, run `flutter run -d <device>`, verify sign-in, expenses, cards, LB, sync
- 👤 **Set signing team in Xcode** — open `ios/Runner.xcworkspace` → Signing & Capabilities → select your Apple Developer team
- 👤 **Place `GoogleService-Info.plist`** in `ios/Runner/` and fill iOS values in `firebase_options.dart`
- 👤 **Change app display name from "Mmm"** — edit `ios/Runner/Info.plist` → `CFBundleDisplayName` to "My Money Manager" (or shorter brand name)
- ⏭ **Bitcode / Xcode version docs** — `ENABLE_BITCODE = NO` is correct for current Xcode; no action needed
- ⏭ **iPad / landscape layouts** — out of scope for now; lock to portrait if not supporting iPad

---

## Android release

- 👤 **Generate signing keystore and configure `android/key.properties`** — see README for exact steps
- 👤 **Run `flutter build apk --release`** after signing is configured

---

## UI improvements still useful

- ✅ **Confirm dialogs on delete** — all delete actions (expense, card txn, cash txn, card, LB entry, default expense) now show an AlertDialog before executing
- ✅ **`createMonthFromDefaults` guard** — button only shows when month is empty so no overwrite risk; Defaults tab already had confirm dialog for `clearAll`
- ⏭ **Replace `ListView(children:[])` with `ListView.builder`** — personal finance lists are typically < 50 items; no measurable gain at this scale
- ⏭ **Use `Selector` instead of `context.watch`** — `context.watch` is correct and simple; `Selector` adds complexity without measurable gain at this scale
- ⏭ **Dark mode** — not planned
- ⏭ **Accessibility / VoiceOver audit** — not planned for v1
- ⏭ **Automated tests / CI** — not planned for v1
- ⏭ **Animation polish** — not planned for v1
