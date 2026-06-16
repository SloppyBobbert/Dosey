# App Background Foundations Design

## Goal

Add the non-UI app foundations needed for a cross-platform Dosey app: Bluetooth communication seams, network/connectivity seams, Apple + Google sign-in support, local notification/sound foundations, permission handling, and matching documentation.

This slice should improve the app's internal platform foundation without committing to cloud sync, push notifications, Wi-Fi provisioning, or a production BLE protocol.

## Scope

This branch covers:

- app-owned interfaces and data models for BLE, connectivity, notifications, and permissions
- Apple sign-in support alongside the existing Google sign-in path
- package integration for the selected platform plugins
- local documentation for Android/iOS setup and platform caveats
- test coverage for the new pure-Dart models, auth behavior, and wrapper seams

This branch does not cover:

- Firebase, Supabase, or any backend auth/session verification
- push notifications
- Wi-Fi provisioning or joining a network from the app
- real BLE command implementation against the ESP32 protocol
- reminder scheduling UX polish or notification timing rules
- animations or visual redesign

## Recommended package set

- `flutter_blue_plus` for BLE central/client behavior against the ESP32 peripheral
- `connectivity_plus` for coarse connectivity state such as wifi/cellular/none
- a native iOS platform channel for Apple sign-in support
- `flutter_local_notifications` for local notifications and sound/channel groundwork
- `permission_handler` for centralized runtime permission requests

These stay behind app-owned interfaces so the app is not tightly coupled to plugin-specific APIs.

## Architecture

### 1. Auth foundation

The existing auth layer already supports Google sign-in through an app-owned `AuthService`. This slice extends that layer to support Apple sign-in while keeping the same session model.

Changes:

- extend `AuthProvider` with `apple`
- extend `AuthService` with `signInWithApple()`
- add an Apple account gateway wrapper similar to the Google wrapper
- keep local cached auth state in Drift as it works today

Design constraints:

- only Google and Apple are supported
- no backend token verification yet
- Apple sign-in is foundation work only; if some platform setup is incomplete, the wrapper should still preserve a clean seam and predictable failure behavior

### 2. BLE foundation

BLE should remain behind an app-owned gateway and should not be wired directly into the UI or business logic.

This slice should add:

- a `BleGateway` interface
- scan/connect/disconnect/watch-state method signatures
- data types for BLE availability, scan result summary, and active connection summary
- a lightweight plugin-backed implementation shell and a fake/test implementation where needed

Design constraints:

- no command protocol coupling yet
- no assumption that Bluetooth connected means Dosey is ready to dispense
- no background BLE mode yet unless strictly required by compilation/setup

### 3. Connectivity foundation

The app needs a way to understand coarse device connectivity without conflating it with BLE readiness.

This slice should add:

- a `ConnectivityGateway` interface
- data model such as `offline`, `wifi`, `cellular`, `other`
- plugin-backed wrapper around `connectivity_plus`

Design constraints:

- connectivity is advisory only
- it must not gate BLE operations directly
- it must not attempt Wi-Fi provisioning or joining

### 4. Notification foundation

The app already has a scheduler interface, but it does not yet model notification channels, sound configuration, or platform setup clearly enough.

This slice should add:

- a stronger notification gateway/scheduler contract
- explicit identifiers for reminder notification channels/categories
- sound configuration constants for the local reminder path
- platform notes for Android channel immutability and iOS bundled sound files

Design constraints:

- this is groundwork, not full scheduling UX
- no remote push support
- keep sound/channel IDs stable and explicit

### 5. Permissions foundation

The current permission layer is too small for the package set above.

This slice should extend permission support to cover:

- Bluetooth scan/connect where relevant
- notifications
- any additional platform permissions required by the selected plugins

The permission layer should stay centralized so screen code can ask for domain-specific permissions without knowing plugin details.

## File shape

Expected new or updated areas:

- `mobile_app/dosey_app/lib/core/auth/` for Apple auth support
- `mobile_app/dosey_app/lib/core/bluetooth/` for BLE models and gateway
- `mobile_app/dosey_app/lib/core/connectivity/` for connectivity models and gateway
- `mobile_app/dosey_app/lib/core/notifications/` for stronger scheduler/sound/channel models
- `mobile_app/dosey_app/lib/core/permissions/` for expanded permission coverage
- `mobile_app/dosey_app/test/core/...` for focused unit tests
- `docs/mobile_stack.md`, `README.md`, and app readmes for setup notes

## Testing strategy

This branch should favor deterministic tests over platform integration tests.

Required test focus:

- auth service behavior for Apple and Google wrapper paths
- permission model and mapping behavior
- BLE/connectivity/notification pure-Dart state models
- fake or stub implementations where wrapper logic exists outside plugins

Verification after implementation should include:

- `dart format .`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- `flutter build ios --debug --no-codesign`

## Risks and trade-offs

- Adding plugin packages now improves architecture readiness but increases platform config surface area.
- Apple sign-in without a backend is acceptable for local prototype flow, but it is not production auth.
- BLE package integration before the protocol is finalized is acceptable only if the branch stops at clean app-owned seams and wrapper setup.
- Notification sound support needs careful documentation because Android channels are sticky and iOS bundles sounds differently.

## Recommendation

Proceed with one branch that adds the package set, app-owned interfaces, wrapper shells, tests, and docs together.

That gives Dosey a realistic Android/iOS app foundation while keeping risky integration details isolated behind seams and leaving the real BLE protocol, cloud sync, and push delivery for later branches.
