# Test plan

Track electronics bring-up, Bluetooth command/status tests, carousel movement tests, chute/cup dispense tests, mobile checks, and failure simulations here.

Do not mark a phase complete until its success criteria were met and logged in `docs/build_log.md`.

## Build stages

### Stage 1: Hardware confirmed

Status: mostly complete.

Goal: confirm board, Grove board/shield, servo, PIR, buttons, LEDs, buzzer/vibration, and sensors work one at a time.

Rules:

- Do not plug everything in at once.
- Unplug USB-C before adding or swapping a module.
- Plug in only the part being tested.
- Do not use the battery connector, SWD pins, or JST LiPo port during early tests.

### Stage 2: Servo and carousel rig

Status: next major build.

Success criteria:

- Servo advances the Daviky carousel one slot.
- Carousel does not roll backward.
- Slot aligns with the chute and cup.
- Movement works repeatedly over at least 10 cycles.
- Failure modes are logged with photos or notes.

### Stage 3: Bluetooth control

Goal: make the phone command the XIAO wirelessly with acknowledgements.

Test commands:

- `STATUS`
- `WAKE_FACE`
- `MOVE_SERVO`
- `DISPENSE_TEST`
- `DISPENSE_NEXT`
- `LED_TEST`
- `PIR_STATUS`
- `HEARTBEAT`

Success criteria:

- Phone sends command.
- XIAO replies with an acknowledgement or error.
- Servo completion is reported separately from dose taken.
- Heartbeat detects offline and reconnect states.

### Stage 4: Basic app MVP

Goal: Robot Mode with schedule, loading guide, dispense, refill, history, and hardware test screens.

MVP checks:

- Manual medication schedule can map doses to carousel slots.
- Manual medication database can store name, instructions, shape/count notes, and refill info.
- Guided loading records how many doses were loaded and the starting slot/index.
- Dose actions include take now, take early, take late, snooze, skip, mark already taken, ask caregiver, and mark missed.
- Refill countdown decreases by dispensed slot and warns at configured thresholds.
- Optional PIN gates only the configured actions.
- Hardware test screen can request status, servo, PIR, LED, and heartbeat checks.

### Stage 5: LEGO body integration

Goal: turn the working rig into a cute, stable, serviceable LEGO robot body.

Success criteria:

- Phone sits horizontally on the front.
- Cup opening stays clear.
- Refill access stays reachable.
- Back or side panels can be removed for debugging.
- LEGO shell does not block the servo arm, carousel, charging cable, controller cable, or cup path.

### Stage 6: Reliability features

Goal: add disconnect warnings, power behavior, refill warnings, missed-dose logic, PIN, error recovery, and index correction.

Failure simulations:

- Bluetooth disconnect.
- XIAO unplugged or reset.
- Servo power brownout or jitter.
- Carousel jam or rollback.
- Cup missing or wrong.
- Missed dose timeout.
- Refill warning ignored.
- Wrong PIN attempts.

### Stage 7: Advanced interaction

Future only: Piper voices, voice commands, local command recognition, local AI experiments, wellness check-ins, caregiver summaries, video shortcut, facial recognition, and caregiver-approved AI responses.

## Current mobile checks

Run these from `mobile_app/dosey_app/` after app changes:

```sh
dart format .
dart run build_runner build
git diff --exit-code -- lib/core/storage/dosey_database.g.dart
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
git diff --check
```

For local-reminder UI changes, widget tests should cover add, edit, enable/disable, and delete behavior against an in-memory Drift database.

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
