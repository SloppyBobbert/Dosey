# Mobile app

Flutter app workspace for Dosey.

The app lives in `mobile_app/dosey_app/` and keeps Android and iOS support in scope from the start.

## Quick status

| Item | Status |
| --- | --- |
| App shell | Today, Reminders, Controller, Log, Settings |
| Local storage | Drift/SQLite |
| Reminders | Local add/edit/delete and enabled state |
| Auth | Google sign-in wrapper, no backend yet |
| Controller | Simulator only; no BLE package yet |
| Builds | Android debug APK and iOS no-codesign debug build run locally |

## Current app

- Flutter/Dart app shell with Today, Reminders, Controller, Log, and Settings tabs.
- Safety-first home/settings copy and safety acknowledgement storage.
- Local Drift/SQLite database for app settings, reminder schedules, cached auth state, and dose logs.
- Simple local reminder add/edit/delete controls with enabled/disabled state.
- Device roles: Android robot phone, Android personal phone, and iOS personal phone only.
- Google sign-in is behind an app-owned interface with no Firebase/Supabase backend yet.
- Controller simulator, notifications, storage, auth, and permission seams stay behind app-owned interfaces.
- First physical test device: 2024 Moto G Play.

Run Flutter commands from `mobile_app/dosey_app/`.

## Local commands

```sh
cd mobile_app/dosey_app
dart format .
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
# After Drift schema changes:
dart run build_runner build
```

Android SDK platforms 35 and 36 and OpenJDK 17 are configured locally for the first Moto G Play builds. Xcode 26.5 and CocoaPods 1.16.2 are configured for local iOS no-codesign builds.
