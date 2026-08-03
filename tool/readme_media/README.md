# README media

From the repository root, verify the Today captures with the app's deterministic UTC clock:

```sh
cd mobile_app/dosey_app
TZ=UTC flutter test ../../tool/readme_media/today_screen_capture_test.dart
```

When an intentional Today UI change needs new reviewed captures, add `--update-goldens` to that command. The composition renderer requires macOS because it uses Apple CoreGraphics, CoreText, and ImageIO frameworks. Return to the repository root and render the device composition:

```sh
cd ../..
swift tool/readme_media/device_showcase/render.swift
```

The capture test injects `DateTime.utc(2040, 1, 2, 9)` through `ControllableAppClock`; `TZ=UTC` also keeps any platform-local behavior stable. The desktop image is a responsive presentation preview, not a shipped or qualified Personal Today app.
