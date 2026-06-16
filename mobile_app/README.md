# Mobile app

Flutter app workspace for Dosey.

The app lives in `mobile_app/dosey_app/` and keeps Android and iOS support in scope from the start.

## Quick status

| Item | Status |
| --- | --- |
| App shell | Today, Reminders, Controller, Log, Settings |
| Local storage | Drift/SQLite |
| Reminders | Local add/edit/delete and enabled state |
| Auth | Google + Apple wrappers, no backend yet |
| Controller | Simulator plus BLE foundation only; protocol incomplete |
| Builds | Android debug APK and iOS no-codesign debug build run locally |

## Current app

- Flutter/Dart app shell with Today, Reminders, Controller, Log, and Settings tabs.
- Safety-first home/settings copy and safety acknowledgement storage.
- Local Drift/SQLite database for app settings, reminder schedules, cached auth state, and dose logs.
- Simple local reminder add/edit/delete controls with enabled/disabled state.
- Device roles: Android robot phone, Android personal phone, and iOS personal phone only.
- `flutter_blue_plus` BLE foundation behind an app-owned interface; protocol still incomplete.
- `connectivity_plus` behind an app-owned interface for advisory connectivity/Wi-Fi status only, not provisioning.
- `google_sign_in` plus a native iOS Apple sign-in bridge behind app-owned auth interfaces with no Firebase/Supabase backend yet.
- `flutter_local_notifications` for local reminder notifications; channel/sound IDs are meant to stay stable, but custom sound assets may still need platform provisioning.
- `permission_handler` behind an app-owned runtime permission interface.
- No cloud sync or push notifications yet.
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

## CI

GitHub Actions runs Mobile CI for pull requests and pushes to `main`. The workflow checks committed whitespace, generated Drift code, formatting, analyzer output, tests, and an Android debug APK build from `mobile_app/dosey_app/`.

The Android debug APK is uploaded as a short-lived workflow artifact for basic install/build confirmation. It is not a release build.

iOS no-codesign builds still run locally because GitHub macOS runners are slower and costlier.
