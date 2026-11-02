# MMM App Improvement TODO

Reviewed on **2 November 2026** from the repository source and configuration. This is a code/configuration review; iOS builds, sign-in, sync, and visual behavior on devices have not been run, so this file does not certify that every feature currently works.

## Priority 0 — Upgrade and stabilize dependencies

- [ ] **Plan a coordinated Flutter/Dart and Firebase upgrade.** `pubspec.yaml` declares Firebase Core `^3.6.0`, Auth `^5.3.1`, and Database `^11.1.4`; `pubspec.lock` resolves them to `3.15.2`, `5.7.0`, and `11.3.10`. Current pub.dev releases are Core `4.5.0`, Auth `7.0.1`, and Database `13.0.1`. Upgrade these as a compatible FlutterFire set and follow their migration notes. [Core](https://pub.dev/packages/firebase_core/versions) · [Auth](https://pub.dev/packages/firebase_auth/versions) · [Database](https://pub.dev/packages/firebase_database)
- [ ] **Migrate Google Sign-In before moving to v7.** The app resolves `google_sign_in 6.3.0` and uses the v6 `GoogleSignIn()` / `signIn()` / `authentication` flow in `lib/services/firebase_service.dart`. The current `7.2.0` release has a newer API; update the service and both native and web sign-in flows together. The separately pinned `google_sign_in_web 0.12.4+4` is also behind current `1.1.3`; check SDK constraints and compatibility before upgrading. [Google Sign-In](https://pub.dev/packages/google_sign_in) · [Web package versions](https://pub.dev/packages/google_sign_in_web/versions)
- [ ] **Raise and document the minimum Dart/Flutter SDK after selecting the upgrade set.** The current constraint is `>=3.0.0 <4.0.0`, while newer web sign-in releases require a newer Dart SDK. Pin the supported Flutter channel/version in project setup or CI so upgrades remain reproducible.
- [ ] **Update the lint and formatting baseline.** `flutter_lints` is constrained to `^4.0.0` and locked at `4.0.0`; current pub.dev version is `6.0.0`. Upgrade after the SDK decision, run analysis, and resolve new warnings intentionally. [flutter_lints](https://pub.dev/packages/flutter_lints)
- [ ] **Update `intl` from `^0.19.0` / locked `0.19.0` to a compatible current release** (pub.dev currently lists `0.20.3`), then verify all currency/date formatting and locales. [intl](https://pub.dev/packages/intl)
- [ ] **Run a dependency audit and record upgrade decisions.** Check every direct and transitive package for discontinued, retracted, vulnerable, or incompatible versions rather than assuming every old-looking lock entry is deprecated. Keep `pubspec.lock` committed for this application and refresh the two iOS `Package.resolved` files together when dependencies change.

## Priority 1 — iOS reliability and release readiness

- [ ] **Build and smoke-test on real iPhone and iPad devices/simulators** for fresh install, returning session, Google sign-in/cancel/sign-out, offline launch, workspace switching, expense/card/LB create-edit-delete, Firebase reconnect, and landscape/rotation. Capture failures and screenshots; repository inspection alone cannot confirm “everything working.”
- [ ] **Check the iOS Google OAuth setup end to end.** `Info.plist` contains a client ID and URL scheme, and `AppDelegate.swift` uses Flutter’s implicit engine registration. Verify these values match the active Firebase iOS app and test the callback on device after the Google Sign-In migration.
- [ ] **Review the iOS deployment and Xcode settings.** The Runner target is iOS 15.0, supports iPhone and iPad, and has `ENABLE_BITCODE = NO`. Confirm iOS 15 is still the intended minimum, check current Flutter/Xcode guidance, remove obsolete build settings where appropriate, and document required Xcode/Swift versions.
- [ ] **Verify release metadata and app identity.** Change the displayed app name from `Mmm` to the chosen branded name, confirm version/build number strategy (`1.0.0+1`), signing team, bundle ID, privacy disclosures, and App Store assets.
- [ ] **Check data privacy and Firebase access rules before release.** Confirm production Realtime Database rules enforce owner/read-only share behavior, test revocation and unauthorized access, and ensure logs/errors do not expose account or financial data. The app handles financial records, so access control deserves an explicit security review.
- [ ] **Add a visible, recoverable loading/error/offline experience.** In `main.dart`, Firebase initialization errors are shown raw, and the Retry button only changes local loading state; it does not rerun initialization or re-subscribe to auth. Implement a real retry path, friendly actionable messages, and explicit sync/offline status.

## Priority 1 — Data safety and sync performance

- [ ] **Stop writing the entire workspace snapshot for each small edit.** `StateProvider` calls `save()` after individual mutations and `FirebaseService.saveState()` replaces `userData/$uid` with the full state. Use targeted updates or a queued/debounced write strategy, surface save failures, and prevent overlapping writes from overwriting newer changes.
- [ ] **Define offline and conflict behavior.** Provide local persistence/cache for core finance data, make pending writes visible, and reconcile concurrent edits from multiple devices/workspaces without silently losing data. `shared_preferences` is present but unused in the inspected feature path; do not use it as the sole store for critical financial records.
- [ ] **Avoid fetching every profile serially when loading shared workspaces.** `getSharedWorkspaces()` performs one profile read per shared owner. Batch or denormalize the minimum profile data needed and handle stale/revoked share entries cleanly.
- [ ] **Add safeguards around destructive and duplicate actions.** Confirm before deletes and clearing data, prevent accidental double-submits, and prevent `createMonthFromDefaults()` from silently replacing an existing month’s expenses.
- [ ] **Close lifecycle gaps.** Cancel the auth-state subscription in `_AuthGateState` when disposed, await/catch provider saves where appropriate, and ensure switching/signing out promptly clears old user data from memory.

## Priority 2 — iOS UI polish and usability

- [ ] **Make the dashboard feel like one intentional finance product.** Establish consistent spacing, typography scale, color roles, corner radius, elevation, and icon style across This Month, Cards, LB, and Defaults. Reduce competing navy blocks and repeated heavy cards; use a clear balance/summary hierarchy with restrained accent color.
- [ ] **Improve iPhone navigation and safe-area behavior.** Replace the custom row navigation in `home_screen.dart` with an accessible Material 3 navigation bar or an explicitly designed equivalent; verify labels, selected state, safe-area insets, keyboard appearance, and bottom-sheet behavior on small phones.
- [ ] **Add richer finance summaries.** Show monthly cash-flow totals, due-soon items, spending by category, credit-card bill progress, and lend/borrow net balance with clear period labels and compact charts. Keep chart colors/labels readable and support empty states.
- [ ] **Polish lists and empty states.** Use consistent category icons/colors, clearer due-date urgency, swipe or explicit quick actions where appropriate, confirmation for delete, and helpful first-run examples or setup prompts. Keep transaction lists scannable when there are many entries.
- [ ] **Improve add/edit forms.** Validate amount and date fields with inline messages, use numeric decimal keyboards, constrain due dates to valid days, keep forms scrollable above the iOS keyboard, and present success/failure feedback. Give the primary action a fixed and reachable position on small screens.
- [ ] **Add motion with purpose.** Use short transitions for tab changes, payment state, adding/removing rows, and summary updates; avoid decorative animation that competes with reading financial figures.
- [ ] **Support accessibility and Dynamic Type.** Audit contrast, text scaling, VoiceOver labels/hints, logical focus order, minimum touch sizes, color-independent status indicators, and Reduce Motion. Several controls currently use `GestureDetector` or very small labels and need explicit semantics/tap-target checks.
- [ ] **Review iPad and landscape layouts.** `Info.plist` allows landscape and iPad, but several screens use dense rows and phone-style bottom navigation. Add adaptive layouts or intentionally lock unsupported orientations after product review.
- [ ] **Add dark mode and user preferences** for theme, currency/locale, first day of month, and notification/reminder preferences where useful.

## Priority 2 — Smoothness and maintainability

- [ ] **Reduce unnecessary rebuilds.** Main tabs call `context.watch<StateProvider>()`, so each provider notification rebuilds entire tab trees. Use `Selector`/smaller consumers and split large screen widgets around data that changes independently.
- [ ] **Use lazy builders for potentially long lists.** Month, card transactions, LB entries, and defaults often build list children eagerly inside `ListView(children: ...)` or nested columns. Move long collections to `ListView.builder`/slivers and profile scrolling performance with realistic data.
- [ ] **Profile release-mode frame time and memory on older supported devices.** Record scroll jank, time-to-first-interaction, cold-start time, and memory before optimizing; keep visual effects and rebuilding within the frame budget.
- [ ] **Separate UI, domain rules, and persistence.** Extract money totals, month/bill calculations, validation, and sync policy into testable units; make Firebase calls return observable success/error state instead of being fire-and-forget.
- [ ] **Add automated coverage for financial calculations and sync behavior.** Cover totals, paid/pending, bill-cycle assignment, repayment balances, default-copy behavior, workspace read-only behavior, serialization/migration, and error/offline states. Add iOS widget/integration coverage for sign-in and core flows.
- [ ] **Add CI checks for formatting, static analysis, tests, and iOS build.** Run the pipeline on dependency updates and release branches; include a dependency-update review cadence.
- [ ] **Remove unused direct dependencies after confirming imports.** `shared_preferences` appears declared but no usage was found in the inspected `lib/` files; remove it if it is not used elsewhere, or implement it for noncritical preferences.

## Suggested delivery order

1. Choose Flutter/Dart baseline and upgrade dependencies, beginning with Google Sign-In API migration and coordinated FlutterFire upgrades.
2. Build and smoke-test iOS authentication and core flows; fix release configuration and data-loss/security risks.
3. Add sync state/offline handling and reduce unnecessary full-state Firebase writes.
4. Refresh navigation, summaries, forms, accessibility, and list performance using real device profiling.
5. Add automated checks and CI so the improvements stay in place.

> **Version note:** Package versions above were checked against pub.dev on 2 November 2026 and are upgrade targets to evaluate, not a claim that upgrades are drop-in compatible. Review package changelogs and SDK constraints during implementation.
