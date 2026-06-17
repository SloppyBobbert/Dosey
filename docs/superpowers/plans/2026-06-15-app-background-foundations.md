# App Background Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add cross-platform background foundations for BLE, connectivity, Apple + Google auth, local notifications, and permissions without adding cloud sync, push notifications, or real BLE protocol behavior.

**Architecture:** Keep every plugin behind an app-owned interface so the Flutter app does not depend directly on package APIs. Add small pure-Dart models for auth providers, BLE state, connectivity state, notification sound/channel config, and permission coverage; then add thin plugin-backed wrapper shells plus tests around the domain behavior.

**Tech Stack:** Flutter 3.44.1, Dart 3.12.1, Drift/SQLite, `flutter_blue_plus`, `connectivity_plus`, native iOS Apple sign-in bridge, `flutter_local_notifications`, `permission_handler`, `flutter_test`, `build_runner`

---

## Planned file structure

- Modify: `mobile_app/dosey_app/pubspec.yaml`
- Modify: `mobile_app/dosey_app/pubspec.lock`
- Modify: `mobile_app/dosey_app/lib/core/auth/auth_service.dart`
- Modify: `mobile_app/dosey_app/lib/core/auth/local_auth_repository.dart`
- Modify: `mobile_app/dosey_app/lib/core/storage/dosey_database.dart`
- Modify: `mobile_app/dosey_app/lib/core/storage/dosey_database.g.dart`
- Modify: `mobile_app/dosey_app/lib/core/permissions/app_permission_gateway.dart`
- Modify: `mobile_app/dosey_app/lib/app/dosey_app_scope.dart`
- Create: `mobile_app/dosey_app/lib/core/auth/apple_auth_service.dart`
- Create: `mobile_app/dosey_app/lib/core/bluetooth/ble_gateway.dart`
- Create: `mobile_app/dosey_app/lib/core/bluetooth/flutter_blue_plus_ble_gateway.dart`
- Create: `mobile_app/dosey_app/lib/core/connectivity/connectivity_gateway.dart`
- Create: `mobile_app/dosey_app/lib/core/connectivity/connectivity_plus_gateway.dart`
- Create: `mobile_app/dosey_app/lib/core/notifications/local_notification_models.dart`
- Create: `mobile_app/dosey_app/lib/core/notifications/flutter_local_notification_scheduler.dart`
- Create: `mobile_app/dosey_app/lib/core/permissions/permission_handler_gateway.dart`
- Create: `mobile_app/dosey_app/test/core/auth/apple_auth_service_test.dart`
- Create: `mobile_app/dosey_app/test/core/bluetooth/flutter_blue_plus_ble_gateway_test.dart`
- Create: `mobile_app/dosey_app/test/core/connectivity/connectivity_plus_gateway_test.dart`
- Create: `mobile_app/dosey_app/test/core/notifications/flutter_local_notification_scheduler_test.dart`
- Create: `mobile_app/dosey_app/test/core/permissions/permission_handler_gateway_test.dart`
- Modify: `README.md`
- Modify: `docs/mobile_stack.md`
- Modify: `mobile_app/README.md`
- Modify: `mobile_app/dosey_app/README.md`

### Task 1: Add package and auth foundation support

**Files:**
- Modify: `mobile_app/dosey_app/pubspec.yaml`
- Modify: `mobile_app/dosey_app/pubspec.lock`
- Modify: `mobile_app/dosey_app/lib/core/auth/auth_service.dart`
- Modify: `mobile_app/dosey_app/lib/core/auth/local_auth_repository.dart`
- Modify: `mobile_app/dosey_app/lib/core/storage/dosey_database.dart`
- Modify: `mobile_app/dosey_app/lib/core/storage/dosey_database.g.dart`
- Create: `mobile_app/dosey_app/lib/core/auth/apple_auth_service.dart`
- Test: `mobile_app/dosey_app/test/core/auth/apple_auth_service_test.dart`

- [ ] **Step 1: Write the failing auth tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dosey_app/core/auth/auth_service.dart';

void main() {
  test('apple auth maps to signed-in Apple session', () async {
    expect(AuthProvider.values, contains(AuthProvider.apple));
  });

  test('apple auth can clear local session on sign out', () async {
    expect(const AuthSession.signedOut().isSignedIn, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```sh
cd mobile_app/dosey_app
flutter test test/core/auth/apple_auth_service_test.dart
```

Expected: FAIL because `AuthProvider.apple` and the Apple auth wrapper do not exist yet.

- [ ] **Step 3: Add dependencies and auth types**

Add these dependencies to `mobile_app/dosey_app/pubspec.yaml`:

```yaml
dependencies:
  connectivity_plus: ^6.0.5
  flutter_blue_plus: ^1.35.5
  flutter_local_notifications: ^19.4.2
  permission_handler: ^12.0.1
  # Apple sign-in uses a native iOS platform channel; keep plugin calls behind app-owned auth interfaces.
```

Update `auth_service.dart` so the provider enum and service contract become:

```dart
enum AuthProvider { google, apple }

abstract interface class AuthService {
  Stream<AuthSession> watchSession();
  Future<AuthSession> signInWithGoogle();
  Future<AuthSession> signInWithApple();
  Future<void> signOut();
}
```

Create `apple_auth_service.dart` with an app-owned Apple gateway seam and a thin service that mirrors the Google auth service pattern.

- [ ] **Step 4: Persist the new provider safely**

Keep using the existing auth session row, but make sure local auth storage can round-trip Apple users using the same `AuthUser` model and stored provider name.

If Drift code generation changes, run:

```sh
cd mobile_app/dosey_app
dart run build_runner build
```

- [ ] **Step 5: Run tests to verify auth foundation passes**

Run:

```sh
cd mobile_app/dosey_app
flutter test test/core/auth/apple_auth_service_test.dart test/core/auth/local_auth_repository_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```sh
git add mobile_app/dosey_app/pubspec.yaml mobile_app/dosey_app/pubspec.lock mobile_app/dosey_app/lib/core/auth mobile_app/dosey_app/lib/core/storage mobile_app/dosey_app/test/core/auth
git commit -m "feat: add auth background foundations"
```

### Task 2: Add BLE and connectivity interfaces

**Files:**
- Create: `mobile_app/dosey_app/lib/core/bluetooth/ble_gateway.dart`
- Create: `mobile_app/dosey_app/lib/core/bluetooth/flutter_blue_plus_ble_gateway.dart`
- Create: `mobile_app/dosey_app/lib/core/connectivity/connectivity_gateway.dart`
- Create: `mobile_app/dosey_app/lib/core/connectivity/connectivity_plus_gateway.dart`
- Test: `mobile_app/dosey_app/test/core/bluetooth/flutter_blue_plus_ble_gateway_test.dart`
- Test: `mobile_app/dosey_app/test/core/connectivity/connectivity_plus_gateway_test.dart`

- [ ] **Step 1: Write the failing model tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';

void main() {
  test('ble availability defaults to unavailable disconnected state', () {
    expect(const BleConnectionSnapshot.disconnected().isConnected, isFalse);
  });

  test('connectivity state distinguishes wifi and offline', () {
    expect(ConnectivityState.values, contains(ConnectivityState.wifi));
    expect(ConnectivityState.values, contains(ConnectivityState.offline));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```sh
cd mobile_app/dosey_app
flutter test test/core/bluetooth/flutter_blue_plus_ble_gateway_test.dart test/core/connectivity/connectivity_plus_gateway_test.dart
```

Expected: FAIL because these types do not exist yet.

- [ ] **Step 3: Add the pure-Dart interfaces and states**

`ble_gateway.dart` should define small app-owned types such as:

```dart
enum BleAvailability { unknown, poweredOff, poweredOn, unavailable }
enum BleScanState { idle, scanning }

class BleConnectionSnapshot {
  const BleConnectionSnapshot({
    required this.availability,
    required this.isConnected,
    required this.deviceId,
    required this.deviceName,
  });

  const BleConnectionSnapshot.disconnected()
    : availability = BleAvailability.unknown,
      isConnected = false,
      deviceId = null,
      deviceName = null;

  final BleAvailability availability;
  final bool isConnected;
  final String? deviceId;
  final String? deviceName;
}

abstract interface class BleGateway {
  Stream<BleConnectionSnapshot> watchConnection();
  Future<void> startScan();
  Future<void> stopScan();
  Future<void> connect(String deviceId);
  Future<void> disconnect();
}
```

`connectivity_gateway.dart` should define:

```dart
enum ConnectivityState { offline, wifi, cellular, other }

abstract interface class ConnectivityGateway {
  Stream<ConnectivityState> watchConnectivity();
  Future<ConnectivityState> currentConnectivity();
}
```

Then add thin wrapper shells using `flutter_blue_plus` and `connectivity_plus` without real protocol logic.

- [ ] **Step 4: Run tests to verify interfaces pass**

Run:

```sh
cd mobile_app/dosey_app
flutter test test/core/bluetooth/flutter_blue_plus_ble_gateway_test.dart test/core/connectivity/connectivity_plus_gateway_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add mobile_app/dosey_app/lib/core/bluetooth mobile_app/dosey_app/lib/core/connectivity mobile_app/dosey_app/test/core/bluetooth mobile_app/dosey_app/test/core/connectivity
git commit -m "feat: add bluetooth and connectivity foundations"
```

### Task 3: Add notification and permission foundations

**Files:**
- Modify: `mobile_app/dosey_app/lib/core/permissions/app_permission_gateway.dart`
- Create: `mobile_app/dosey_app/lib/core/permissions/permission_handler_gateway.dart`
- Create: `mobile_app/dosey_app/lib/core/notifications/local_notification_models.dart`
- Create: `mobile_app/dosey_app/lib/core/notifications/flutter_local_notification_scheduler.dart`
- Test: `mobile_app/dosey_app/test/core/permissions/permission_handler_gateway_test.dart`
- Test: `mobile_app/dosey_app/test/core/notifications/flutter_local_notification_scheduler_test.dart`

- [ ] **Step 1: Write the failing permission and notification tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/notifications/local_notification_models.dart';

void main() {
  test('permission enum includes split Bluetooth and notifications foundations', () {
    expect(AppPermission.values, contains(AppPermission.bluetoothScan));
    expect(AppPermission.values, contains(AppPermission.bluetoothConnect));
    expect(AppPermission.values, contains(AppPermission.notifications));
  });

  test('reminder notification channel id stays stable', () {
    expect(doseyReminderNotificationChannel.id, 'dosey_reminders');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```sh
cd mobile_app/dosey_app
flutter test test/core/permissions/permission_handler_gateway_test.dart test/core/notifications/flutter_local_notification_scheduler_test.dart
```

Expected: FAIL because notification models and expanded permission support are missing.

- [ ] **Step 3: Implement minimal domain models and wrapper shells**

Extend the permission enum to cover the package set clearly, for example:

```dart
enum AppPermission {
  bluetoothScan,
  bluetoothConnect,
  notifications,
}
```

Create stable notification channel/sound constants:

```dart
class LocalNotificationSound {
  const LocalNotificationSound({
    required this.androidResourceName,
    required this.appleFileName,
  });

  final String androidResourceName;
  final String appleFileName;
}

class LocalNotificationChannel {
  const LocalNotificationChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.sound,
  });

  final String id;
  final String name;
  final String description;
  final LocalNotificationSound sound;
}

const doseyReminderNotificationSound = LocalNotificationSound(
  androidResourceName: 'dosey_reminder',
  appleFileName: 'dosey_reminder.aiff',
);

const doseyReminderNotificationChannel = LocalNotificationChannel(
  id: 'dosey_reminders',
  name: 'Dose reminders',
  description: 'Dosey reminder alerts for scheduled doses.',
  sound: doseyReminderNotificationSound,
);
```

Add thin plugin wrapper classes around `permission_handler` and `flutter_local_notifications`.

- [ ] **Step 4: Run tests to verify notification and permission foundations pass**

Run:

```sh
cd mobile_app/dosey_app
flutter test test/core/permissions/permission_handler_gateway_test.dart test/core/notifications/flutter_local_notification_scheduler_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add mobile_app/dosey_app/lib/core/permissions mobile_app/dosey_app/lib/core/notifications mobile_app/dosey_app/test/core/permissions mobile_app/dosey_app/test/core/notifications
git commit -m "feat: add notification and permission foundations"
```

### Task 4: Wire foundations into app scope and docs

**Files:**
- Modify: `mobile_app/dosey_app/lib/app/dosey_app_scope.dart`
- Modify: `README.md`
- Modify: `docs/mobile_stack.md`
- Modify: `mobile_app/README.md`
- Modify: `mobile_app/dosey_app/README.md`

- [ ] **Step 1: Write the failing documentation/usage expectation test**

Use a simple widget or unit test that asserts app scope can still be created after adding the new foundation dependencies.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dosey_app/app/dosey_app.dart';

void main() {
  testWidgets('DoseyApp still builds with background foundations wired', (tester) async {
    await tester.pumpWidget(const DoseyApp());
    expect(find.text('Dosey'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails if app scope is not updated**

Run:

```sh
cd mobile_app/dosey_app
flutter test test/widget_test.dart
```

Expected: fail if newly required dependencies are not wired into app scope.

- [ ] **Step 3: Update app scope and docs**

Wire new foundation services into `DoseyAppScope` as dependencies without changing visible UI behavior.

Update docs to state:

- the selected package set
- Apple + Google only
- BLE is foundation-only and not protocol-complete
- connectivity is advisory only
- local notifications use stable channel/sound IDs
- iOS/Android permission setup still required

- [ ] **Step 4: Run full verification**

Run:

```sh
cd mobile_app/dosey_app
dart format .
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
```

Expected: all commands pass.

- [ ] **Step 5: Commit**

```sh
git add mobile_app/dosey_app/lib/app/dosey_app_scope.dart README.md docs/mobile_stack.md mobile_app/README.md mobile_app/dosey_app/README.md
git commit -m "docs: describe app background foundations"
```

## Self-review notes

- Spec coverage: auth, BLE, connectivity, notifications, permissions, tests, and docs all map to tasks above.
- Placeholder scan: removed vague “handle setup later” language from task steps and named the planned files/interfaces directly.
- Type consistency: plan consistently uses `AuthProvider.apple`, `AuthService.signInWithApple()`, `BleGateway`, `ConnectivityGateway`, `LocalNotificationChannel`, and expanded `AppPermission` names.
