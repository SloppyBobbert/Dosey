# Local App Basics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Dosey's local-first app skeleton: basic navigation, local reminder schedules, local settings/onboarding state, local dose log actions, controller simulator state, and Google sign-in behind an app-owned interface.

**Architecture:** Keep all behavior local-first and testable. Drift owns persisted app data; small repository/service interfaces own auth, settings, reminders, dose logs, and controller state. UI screens consume simple repositories/services and must preserve the safety rule that controller dispense success never marks a dose taken.

**Tech Stack:** Flutter 3.44.1, Dart 3.12.1, Material 3, Drift/SQLite, `google_sign_in`, Flutter widget/unit tests.

---

## File Structure

- Modify `mobile_app/dosey_app/lib/core/storage/dosey_database.dart` to add tables for reminder schedules, auth session cache, safety acknowledgement, and controller simulator state.
- Regenerate `mobile_app/dosey_app/lib/core/storage/dosey_database.g.dart` with `dart run build_runner build` after schema edits.
- Create `mobile_app/dosey_app/lib/core/reminders/reminder_schedule.dart` for reminder domain model.
- Create `mobile_app/dosey_app/lib/core/reminders/local_reminder_repository.dart` for Drift-backed CRUD.
- Create `mobile_app/dosey_app/lib/core/auth/auth_service.dart` for app-owned auth types and interface.
- Create `mobile_app/dosey_app/lib/core/auth/local_auth_repository.dart` for cached local auth state.
- Create `mobile_app/dosey_app/lib/core/auth/google_auth_service.dart` for the `google_sign_in` adapter.
- Create `mobile_app/dosey_app/lib/core/controller/simulated_controller_gateway.dart` for a local demo controller.
- Create `mobile_app/dosey_app/lib/app/dosey_app_scope.dart` for dependency construction and injection.
- Replace the single home screen with a tab shell under `mobile_app/dosey_app/lib/features/shell/`.
- Create screens under `mobile_app/dosey_app/lib/features/today/`, `features/reminders/`, `features/controller/`, `features/log/`, and `features/settings/`.
- Add tests in `mobile_app/dosey_app/test/core/auth/`, `test/core/reminders/`, `test/core/controller/`, and update widget tests.
- Update `README.md`, `docs/mobile_stack.md`, `mobile_app/README.md`, and `mobile_app/dosey_app/README.md` after implementation.

## Task 1: Drift schema and local reminder repository

**Files:**
- Modify: `mobile_app/dosey_app/lib/core/storage/dosey_database.dart`
- Create: `mobile_app/dosey_app/lib/core/reminders/reminder_schedule.dart`
- Create: `mobile_app/dosey_app/lib/core/reminders/local_reminder_repository.dart`
- Test: `mobile_app/dosey_app/test/core/reminders/local_reminder_repository_test.dart`

- [ ] **Step 1: Write failing repository tests**

Create tests that use `DoseyDatabase.inMemory()` and verify:
- `watchSchedules()` starts empty.
- `upsertSchedule()` persists a schedule with id, label, hour, minute, enabled flag, and stable UTC timestamps.
- `deleteSchedule()` removes the schedule.

- [ ] **Step 2: Run red test**

Run from `mobile_app/dosey_app/`:

```sh
flutter test test/core/reminders/local_reminder_repository_test.dart
```

Expected: fail because reminder repository/model/table do not exist.

- [ ] **Step 3: Implement reminder table and repository**

Add a `ReminderSchedules` Drift table with `id`, `label`, `hour`, `minute`, `isEnabled`, `createdAt`, and `updatedAt`. Add `ReminderSchedule` domain model and `LocalReminderRepository` with `watchSchedules()`, `upsertSchedule()`, and `deleteSchedule()`.

- [ ] **Step 4: Generate Drift code**

Run:

```sh
dart run build_runner build
```

Expected: generated database code updates with the new table.

- [ ] **Step 5: Verify green**

Run:

```sh
flutter test test/core/reminders/local_reminder_repository_test.dart
```

Expected: all reminder repository tests pass.

## Task 2: Auth abstraction, local auth cache, and Google adapter setup

**Files:**
- Modify: `mobile_app/dosey_app/pubspec.yaml`
- Modify: `mobile_app/dosey_app/lib/core/storage/dosey_database.dart`
- Create: `mobile_app/dosey_app/lib/core/auth/auth_service.dart`
- Create: `mobile_app/dosey_app/lib/core/auth/local_auth_repository.dart`
- Create: `mobile_app/dosey_app/lib/core/auth/google_auth_service.dart`
- Test: `mobile_app/dosey_app/test/core/auth/local_auth_repository_test.dart`

- [ ] **Step 1: Write failing auth cache tests**

Verify the auth cache starts signed out, saves a local user with Google id/email/display name/photo URL, and clears the user on sign-out.

- [ ] **Step 2: Run red test**

Run:

```sh
flutter test test/core/auth/local_auth_repository_test.dart
```

Expected: fail because auth repository/types/table do not exist.

- [ ] **Step 3: Add dependency**

Run:

```sh
flutter pub add google_sign_in
```

- [ ] **Step 4: Implement auth types and local cache**

Add `AuthUser`, `AuthSession`, and `AuthService` interface with `watchSession()`, `signInWithGoogle()`, and `signOut()`. Add an `AuthSessions` table and `LocalAuthRepository` for local cache persistence.

- [ ] **Step 5: Implement Google adapter without wiring it to cloud**

Create `GoogleAuthService` that depends on `GoogleSignIn` and `LocalAuthRepository`. It converts Google account data to `AuthUser`, stores it locally, and exposes auth state through the app-owned interface. Do not add Firebase/Supabase.

- [ ] **Step 6: Generate and verify**

Run:

```sh
dart run build_runner build
flutter test test/core/auth/local_auth_repository_test.dart
```

Expected: auth cache tests pass.

## Task 3: App scope and tab shell

**Files:**
- Modify: `mobile_app/dosey_app/lib/app/dosey_app.dart`
- Create: `mobile_app/dosey_app/lib/app/dosey_app_scope.dart`
- Create: `mobile_app/dosey_app/lib/features/shell/dosey_shell.dart`
- Create: `mobile_app/dosey_app/lib/features/today/today_screen.dart`
- Create: `mobile_app/dosey_app/lib/features/reminders/reminders_screen.dart`
- Create: `mobile_app/dosey_app/lib/features/controller/controller_screen.dart`
- Create: `mobile_app/dosey_app/lib/features/log/dose_log_screen.dart`
- Create: `mobile_app/dosey_app/lib/features/settings/settings_screen.dart`
- Test: `mobile_app/dosey_app/test/widget_test.dart`

- [ ] **Step 1: Write failing widget tests**

Update widget tests to expect tabs named `Today`, `Reminders`, `Controller`, `Log`, and `Settings`; safety guidance; and controller manual dispense disabled by default.

- [ ] **Step 2: Run red widget test**

Run:

```sh
flutter test test/widget_test.dart
```

Expected: fail because the tab shell does not exist.

- [ ] **Step 3: Implement `DoseyAppScope`**

Create the app database and repositories once, expose them with an `InheritedWidget`, and close the database when the root state is disposed.

- [ ] **Step 4: Implement tab shell and basic screens**

Use `NavigationBar` with five destinations. Keep visuals plain. Each screen should show basic local-first content and no animations.

- [ ] **Step 5: Verify widget test**

Run:

```sh
flutter test test/widget_test.dart
```

Expected: widget tests pass.

## Task 4: Settings, device role, and safety acknowledgement UI

**Files:**
- Modify: `mobile_app/dosey_app/lib/features/settings/settings_screen.dart`
- Modify: `mobile_app/dosey_app/lib/core/settings/local_app_settings_repository.dart`
- Test: `mobile_app/dosey_app/test/core/settings/local_app_settings_repository_test.dart`
- Test: `mobile_app/dosey_app/test/widget_test.dart`

- [ ] **Step 1: Write failing tests**

Verify settings can persist safety acknowledgement and that device role choices include Android robot/personal but keep iOS personal-only in the role model.

- [ ] **Step 2: Implement settings persistence**

Extend `LocalAppSettingsRepository` with `watchSafetyAcknowledged()` and `setSafetyAcknowledged(bool acknowledged)` using the existing app settings table.

- [ ] **Step 3: Implement settings screen controls**

Show current auth state, device role selector, safety acknowledgement checkbox, and local setup notes. Do not allow an iOS robot option.

- [ ] **Step 4: Verify settings tests**

Run:

```sh
flutter test test/core/settings test/widget_test.dart
```

Expected: all settings tests pass.

## Task 5: Local dose log actions and controller simulator

**Files:**
- Modify: `mobile_app/dosey_app/lib/core/logging/dose_log_repository.dart`
- Create: `mobile_app/dosey_app/lib/core/controller/simulated_controller_gateway.dart`
- Modify: `mobile_app/dosey_app/lib/features/controller/controller_screen.dart`
- Modify: `mobile_app/dosey_app/lib/features/log/dose_log_screen.dart`
- Modify: `mobile_app/dosey_app/lib/features/today/today_screen.dart`
- Test: `mobile_app/dosey_app/test/core/controller/simulated_controller_gateway_test.dart`
- Test: `mobile_app/dosey_app/test/core/app_interfaces_test.dart`

- [ ] **Step 1: Write failing tests**

Verify the simulated controller can connect/disconnect, cannot request dispense while disconnected, and emits a controller dispense success event that does not mark a dose taken. Verify `DoseLogEvent.doseTakenConfirmed()` marks a dose taken.

- [ ] **Step 2: Implement dose-taken factory and simulator**

Add `DoseLogEvent.doseTakenConfirmed()` and `SimulatedControllerGateway`. Keep simulator behavior clearly labeled as demo-only.

- [ ] **Step 3: Implement screens**

Controller screen shows connection state, simulated connect/disconnect, and gated manual dispense. Log screen lists local dose log events. Today screen shows next local reminders and a manual taken confirmation button.

- [ ] **Step 4: Verify tests**

Run:

```sh
flutter test test/core/controller test/core/app_interfaces_test.dart test/widget_test.dart
```

Expected: tests pass and safety rule remains covered.

## Task 6: Docs and full verification

**Files:**
- Modify: `README.md`
- Modify: `docs/mobile_stack.md`
- Modify: `mobile_app/README.md`
- Modify: `mobile_app/dosey_app/README.md`
- Modify local ignored `AGENTS.md` files only if project instructions need setup updates.

- [ ] **Step 1: Update docs**

Document that the app now has local-first tabs, local reminder schedules, device role settings, local auth cache, Google sign-in interface, controller simulator, and local dose log actions. State that there is still no Firebase/Supabase/cloud sync and no BLE package.

- [ ] **Step 2: Run final verification**

Run from `mobile_app/dosey_app/`:

```sh
dart format .
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
flutter doctor -v
```

Expected: format changes are intentional, analyzer has no issues, all tests pass, Android and iOS debug builds succeed, and Flutter doctor reports no issues.

- [ ] **Step 3: Inspect status before commit**

Run from the worktree root:

```sh
git status --short --ignored --branch
git diff --stat
git log --oneline -10
```

Expected: only intended app/docs changes are tracked or untracked. Ignored `AGENTS.md`, build outputs, `.dart_tool/`, IDE files, and local platform generated files must remain uncommitted.

## Self-Review

- Scope covered: local app navigation, reminders, settings, Google sign-in interface, auth cache, controller simulator, local dose log, docs, and verification.
- Out of scope by design: animations, Firebase/Supabase/cloud database, real BLE package, real notification plugin, and production Google OAuth console configuration.
- Safety requirements preserved: no dose is marked taken from servo/controller movement; controller dispense success and taken confirmation remain separate event kinds.
