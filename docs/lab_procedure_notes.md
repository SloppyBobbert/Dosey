# Dosey Lab Procedure Notes

## Purpose

This document records the basic procedures followed when working in the Dosey repository so future students can get started without losing time to missing or outdated information.

This is not a polished final build guide for the robot. It is a practical "what we actually did" procedure note based on the current state of the repo.

## Repository used

- Repo root: [`README.md`](../README.md)
- Mobile workspace: [`mobile_app/README.md`](../mobile_app/README.md)
- Flutter app: [`mobile_app/dosey_app/README.md`](../mobile_app/dosey_app/README.md)
- Firmware notes: [`firmware/README.md`](../firmware/README.md)
- Mechanical notes: [`mechanical/README.md`](../mechanical/README.md)

## External references used

These are the main external references that are useful for reproducing the current procedures:

- Flutter install and setup: <https://docs.flutter.dev/get-started/install>
- Flutter test command reference: <https://docs.flutter.dev/testing>
- Dart `build_runner` docs: <https://dart.dev/tools/build_runner>
- Drift docs: <https://drift.simonbinder.eu/>
- GitHub Actions workflow reference: <https://docs.github.com/actions>

## Important repo reality check

Before following any procedure, note these current conditions:

1. The root `README.md` references several files under `docs/` such as `docs/safety.md`, `docs/wiring.md`, `docs/protocol.md`, and `docs/test_plan.md`.
2. In the current checkout, that `docs/` directory was not present.
3. The most complete working instructions currently live in the root README and the two mobile READMEs.
4. The firmware and mechanical folders currently contain README notes only, not full implementation files or full step-by-step lab procedures.

Because of that, the mobile app is the clearest subsystem to reproduce right now.

## Basic procedure followed

### Procedure 1: Open the repository and inspect the real project layout

1. Open the repository root.
2. Read the root [`README.md`](../README.md) first.
3. Confirm the actual folders present:
   - `firmware/`
   - `mechanical/`
   - `mobile_app/`
   - `.github/`
4. Verify whether the referenced `docs/` folder exists before relying on README links.

### Procedure 2: Identify which subsystem is currently reproducible

Based on the repository contents:

- **Mobile app** has the most complete and testable procedure.
- **Firmware** has bring-up notes only.
- **Mechanical** has build direction and success criteria notes only.

For that reason, the main reproducible lab workflow currently centers on the Flutter mobile app.

### Procedure 3: Move into the Flutter app directory

Run all Flutter-related commands from:

```sh
cd mobile_app/dosey_app
```

This matters because the repo has multiple README files, but the actual Flutter app project is inside `mobile_app/dosey_app/`.

### Procedure 4: Install Flutter project dependencies

Run:

```sh
flutter pub get
```

This step appears in `mobile_app/dosey_app/README.md` and should be done before formatting, code generation, analysis, testing, or builds.

### Procedure 5: Format and generate code

Run:

```sh
dart format .
dart run build_runner build
git diff --exit-code -- lib/core/storage/dosey_database.g.dart
```

Why this was necessary:

- The app uses Drift/SQLite.
- Generated database files must stay in sync.
- The `git diff --exit-code` step checks whether generated code changed and was not committed.

### Procedure 6: Run analyzer and tests

Run:

```sh
flutter analyze
flutter test
git diff --check
```

What this checks:

- `flutter analyze` catches static issues.
- `flutter test` runs the app's unit and widget tests.
- `git diff --check` catches whitespace problems that CI also cares about.

### Procedure 7: Build the app locally

Run:

```sh
flutter build apk --debug
flutter build ios --debug --no-codesign
```

Notes:

- Android debug build is part of the documented local and CI workflow.
- iOS no-codesign build is documented as local-only and requires macOS/Xcode in a real local environment.
- If you are not on macOS with Xcode configured, expect the iOS build step to be unavailable.

### Procedure 8: Review the CI workflow for expected checks

Read:

- [`.github/workflows/mobile-ci.yml`](../.github/workflows/mobile-ci.yml)

The README states that CI checks:

- whitespace
- generated Drift code
- formatting
- analyzer output
- tests
- Android debug APK build

This is useful because it tells future students what "done" looks like even if local instructions are incomplete.

### Procedure 9: Firmware procedure actually available right now

The current firmware README supports a **planning/bring-up order**, not a full runnable build procedure.

Current basic firmware procedure from [`firmware/README.md`](../firmware/README.md):

1. Do a blink/serial sanity check.
2. Check button/buzzer basics if available.
3. Test Grove outputs such as LED or vibration motor.
4. Test Grove inputs such as Mini PIR and buttons.
5. Run sensor checks.
6. Run an I2C scanner.
7. Run a servo sweep.
8. Test one-slot carousel movement.
9. Add Bluetooth command/status demo.
10. Add heartbeat/offline behavior.

Important limitation:

- The repo currently says **"No firmware build command exists yet."**
- That means future students will need either an Arduino IDE or PlatformIO procedure added later.

### Procedure 10: Mechanical procedure actually available right now

The current mechanical README supports a **prototype build target**, not a full assembly manual.

Current basic mechanical procedure from [`mechanical/README.md`](../mechanical/README.md):

1. Mount a servo so the arm can push the Daviky carousel.
2. Advance the carousel one slot.
3. Prevent rollback with a ratchet or physical stop.
4. Return the servo arm.
5. Verify the next dose aligns with the chute and cup.

Current success criteria:

- one-slot movement works
- rollback is prevented
- chute/cup alignment is correct
- repeated movement succeeds for at least 10 cycles

## Modifications and clarifications required based on existing documentation

These are the main changes or clarifications we had to make while following the repo documentation.

### 1. Create a real `docs/` folder and store procedure notes there

**Problem:** The root README links to multiple `docs/*.md` files, but the `docs/` directory was missing in this checkout.

**Modification made:** Create a `docs/` directory and store procedure documentation here so future students have an actual place to find it.

### 2. Use the mobile app as the primary reproducible lab workflow

**Problem:** The repo describes firmware, mechanical, and mobile work, but only the mobile app currently has enough detail to follow a real step-by-step verification workflow.

**Modification made:** Treat the Flutter app as the main documented lab procedure until firmware and mechanical build instructions are expanded.

### 3. Always run Flutter commands from `mobile_app/dosey_app`

**Problem:** The repo is multi-folder, and a student could easily try to run Flutter commands from the repo root or `mobile_app/`.

**Modification made:** Explicitly document the working directory:

```sh
cd mobile_app/dosey_app
```

### 4. Add `flutter pub get` to the practical setup flow

**Problem:** The root README and `mobile_app/README.md` list verification commands, but the app README is the only one that clearly includes `flutter pub get`.

**Modification made:** Put `flutter pub get` near the top of the procedure so dependency setup happens before code generation and tests.

### 5. Treat firmware README as planning notes, not a complete lab

**Problem:** `firmware/README.md` gives a good bring-up order but does not provide:

- exact board package installation steps
- Arduino IDE setup steps
- PlatformIO setup steps
- exact compile/upload commands

**Modification made:** Document firmware as a partial procedure and state clearly that a full build/upload procedure still needs to be written.

### 6. Treat mechanical README as prototype direction, not full assembly documentation

**Problem:** `mechanical/README.md` defines goals and success criteria, but not exact measurements, part mounting order, photos, or tool list.

**Modification made:** Document it as a prototype checklist rather than a finished assembly guide.

### 7. Prefer the root README for current feature scope

**Problem:** `mobile_app/dosey_app/README.md` appears older and describes a smaller tab set than the current root/mobile documentation.

**Modification made:** Use the root README and `mobile_app/README.md` as the main source of truth for current app scope, then use the app README mostly for local command details and toolchain notes.

## Recommended future documentation updates

To make this easier for future students, the repository should add:

1. `docs/safety.md`
2. `docs/wiring.md`
3. `docs/protocol.md`
4. `docs/test_plan.md`
5. `docs/parts.md`
6. `docs/build_log.md`
7. A firmware setup guide with:
   - Arduino IDE or PlatformIO version
   - board package install steps
   - upload steps
   - sample serial monitor procedure
8. A mechanical assembly guide with:
   - photos
   - servo mounting geometry
   - parts list
   - repeated one-slot test checklist

## Suggested submission summary

If you need a short summary to paste into a class submission, you can use this:

> I documented the procedures we could actually reproduce from the current Dosey repository. The most complete workflow is the Flutter mobile app under `mobile_app/dosey_app`, where the procedure is: run `flutter pub get`, format code, generate Drift files with `build_runner`, verify generated code is committed, run `flutter analyze`, run `flutter test`, and build Android/iOS debug targets as available. I also documented the current firmware bring-up order and mechanical one-slot servo test procedure from the repo READMEs. The main documentation issue was that the root README referenced several `docs/*.md` files that were not present, so I added procedure notes and listed the missing documentation that future students should create.

