# Mobile app

Flutter app workspace for Dosey.

The app lives in `mobile_app/dosey_app/` and keeps Android and iOS support in scope from the start.

## Current app

- Flutter/Dart app shell.
- Safety-first home screen.
- Local Drift/SQLite database for app settings and dose logs.
- Device roles: Android robot phone, Android personal phone, and iOS personal phone only.
- Controller, notifications, storage, and permission seams stay behind app-owned interfaces.
- First physical test device: 2024 Moto G Play.

Run Flutter commands from `mobile_app/dosey_app/`.

## Local commands

```sh
cd mobile_app/dosey_app
dart format .
flutter analyze
flutter test
flutter build apk --debug
# After Drift schema changes:
dart run build_runner build
```

Android SDK platforms 35 and 36 and OpenJDK 17 are configured locally for the first Moto G Play builds. Xcode 26.5 and CocoaPods 1.16.2 are configured for local iOS no-codesign builds.
