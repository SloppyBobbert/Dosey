# Mobile app

Flutter app workspace for Dosey.

The app lives in `mobile_app/dosey_app/` and keeps Android and iOS support in scope from the start.

## Current app

- Flutter/Dart app shell.
- Safety-first home screen.
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
```

Android SDK 36 and OpenJDK 17 are configured locally for the first Moto G Play builds. CocoaPods is installed, but iOS builds still need a full Xcode install.
