# Test plan

Track electronics bring-up, BLE command/status tests, carousel movement tests, chute/cup dispense tests, and failure simulations here.

Do not mark a phase complete until its success criteria were met and logged.

## Current mobile checks

Run these from `mobile_app/dosey_app/` after app changes:

```sh
dart format .
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
flutter doctor -v
```

For the current local-reminder UI, widget tests should cover add, edit, enable/disable, and delete behavior against an in-memory Drift database.

## Current CI checks

GitHub Actions runs Mobile CI on pull requests and pushes to `main`.

The CI job runs from `mobile_app/dosey_app/` on Ubuntu:

```sh
flutter pub get
dart run build_runner build
git diff --exit-code -- lib/core/storage/dosey_database.g.dart
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

The workflow also runs `git diff --check` against the changed commit range and uploads the Android debug APK as a short-lived artifact. iOS no-codesign builds stay local for now because they need macOS runners.
