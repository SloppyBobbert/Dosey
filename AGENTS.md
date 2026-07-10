# Dosey agent notes

Dosey is a low-cost, open-source medication-dispensing companion robot prototype: premade Daviky pill carousel + mounted Android phone face/app + XIAO ESP32-C6 controller with Grove modules + fully LEGO shell. It is not a medical-grade device.

## Current source of truth

- Active direction: premade Daviky pill carousel, not a six-bottle spinner or pill-counting machine. Each compartment holds one scheduled dose; do not count individual pills.
- Mechanical direction: servo pusher advances the Daviky carousel one slot; ratchet/physical stop prevents rollback; Daviky chute/cup are part of the path; shell is fully LEGO after repeatable movement works.
- Mobile app: Flutter/Dart under `mobile_app/dosey_app/`; Android-first Robot Mode for the mounted phone, plus Personal Mode on Android/iOS.
- Device roles: Android can be the robot phone or a personal phone; iOS can only be a personal phone and cannot be the embedded robot phone.
- Phone is the brain: schedule, med database, refill tracking, dose history, face/voice/sounds, UI, PIN, caregiver placeholders, Bluetooth commands, and local data belong in the Flutter app.
- XIAO is hardware-only: servo, PIR, LEDs, buzzer/vibration, buttons, sensors, carousel commands, Bluetooth/status. It should not handle med names, schedules, dose decisions, caregiver logic, voice/AI, PIN, or medical advice.
- Controller: confirmed Seeed Studio XIAO ESP32-C6.
- Grove base: confirmed Seeed Studio Grove Base for XIAO. Older ESP32S3 and XIAO Expansion Board references are historical notes.
- Local data: Flutter app uses Drift/SQLite for app settings, reminder schedules, cached auth state, and dose logs. The ESP32 should not run SQLite; cloud sync comes later.
- Auth: Google sign-in and native iOS Apple sign-in are wired through app-owned interfaces; no Firebase/Supabase backend yet. Android Apple sign-in is intentionally unavailable in the prototype.
- Current app shell: Today, Reminders, Controller, Log, and Settings tabs with local safety acknowledgement, controller simulator, reminder storage, and dose log actions.
- Background foundations: BLE, connectivity, local notification scheduling/sounds, runtime permissions, Google sign-in, native iOS Apple sign-in, and local persistence sit behind app-owned interfaces. BLE is transport groundwork only; the real controller protocol is still incomplete. Connectivity is advisory status only, not Wi-Fi provisioning.
- Project-plan docs were merged in PR #6. `README.md`, `docs/`, and `mobile_app/README.md` reflect the Daviky/Grove/LEGO/Robot Mode direction; keep them aligned when setup changes.

## Safety constraints

- Test only with candy, beads, dry beans, vitamins, or fake pills during prototyping. Do not use real prescription medication in early tests.
- Do not mark a dose taken because the servo moved. Track command sent, servo done, visible/correct, confirmed taken, skipped, missed, and error as separate states.
- Missed-dose copy must not advise double dosing. Use: “This dose was missed. Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.”
- Motors must not be powered from the phone or directly through XIAO pins. Use suitable power/driver paths and shared ground when needed.
- Add movement timeouts, cancel/emergency stop behavior, and fail-safe error reporting for jams, cup missing, lid open, power interruption, BLE disconnects, and missed doses.
- Never remove safety warnings.

## Build order

1. Hardware bring-up: blink/serial, Grove modules, buttons, buzzer/vibration, LEDs, PIR, servo sweep.
2. Servo/carousel rig: Daviky carousel inspection, LEGO-mounted servo pusher, one-slot advance, no rollback, chute/cup alignment, repeated movement.
3. Bluetooth command/status demo: `STATUS`, `HEARTBEAT`, `WAKE_FACE`, `MOVE_SERVO`, `DISPENSE_TEST`, `DISPENSE_NEXT`, `LED_TEST`, `PIR_STATUS`.
4. Basic app MVP in parallel: schedule setup, manual med database, guided Daviky loading, reminders, dispense button, history, refill countdown, optional PIN, hardware test, heartbeat/offline handling.
5. LEGO body integration only after Stage 2 movement criteria pass.
6. Reliability: jams, missed doses, power interruption, BLE disconnects, servo power issues, offline/reconnect logs.
7. Advanced interaction later: voice commands, local AI, cloud caregiver dashboard, camera/facial recognition, auto pill identification, proof swallowed.

Do not polish the app or shell before proving carousel movement and fake-dose delivery.

## Current mobile setup

- PR #5 (`app-background-foundations`), PR #6 (`update-project-plan`), PR #17 (`robot-mode-mvp`), and PR #18 (`comments-plus-small-refactor`) are merged. Before starting unrelated new work, fetch and start from updated `origin/main` unless told otherwise.
- Active app PR: #19 (`reminder-missed-reliability`) is open at `https://github.com/SloppyBobbert/Dosey/pull/19`; local branch `reminder-missed-reliability` tracks `origin/reminder-missed-reliability`.
- PR #19 adds local missed-dose reconciliation with a fixed 2-hour grace period, startup catchup for today/yesterday, a dedicated 15-minute app-open reconciliation timer, best-effort error logging, and conservative schedule create/edit guards to avoid unsafe backfill.
- PR #19 keeps controller movement separate from taken confirmation: missed-dose events do not decrement inventory, do not imply the dose was taken, suppress duplicate terminal events in the DB-backed path, and retire loaded/dispensed carousel slots to `needsReview` when auto-marking missed.
- PR #19 adds `mobile_app/dosey_app/lib/core/reminders/missed_dose_policy.dart`, `mobile_app/dosey_app/lib/core/reminders/missed_dose_reconciliation_service.dart`, optional test injection hooks in `DoseyApp`/`DoseyAppScope`, and shared app-scope test fakes in `mobile_app/dosey_app/test/support/fake_app_scope_dependencies.dart`.
- Latest PR #19 local gate after review fixes passed from `mobile_app/dosey_app/`: `dart format --set-exit-if-changed ...`, `flutter analyze`, targeted affected tests, full `flutter test` (`295` tests), and `git diff --check`. Latest pushed commit is `9983042` (`fix: address missed-dose review notes`).
- Do not add unrelated feature scope to PR #19. If changes are needed, keep them to review fixes, concise comments, or validation. Good follow-up PRs after #19: protocol simulator + local robot event DB, PIN/action gating MVP, Robot Mode/manual device QA, Android/iOS debug builds, and BLE/controller dispense lifecycle hardening.
- Current local-only artifacts are intentionally uncommitted/unpushed: `.gitignore` has a local `.superpowers/` ignore addition, and `.slim/` is untracked. Do not include either in app/code PRs unless explicitly asked.
- The updated project plan Word file is local/private input only: `/Users/brandontran/Dosey/.Dosey_Updated_Project_Plan.docx`. Keep both visible and hidden copies ignored; never commit `.docx` planning files or Word temp files.
- Flutter 3.44.1 stable and Dart 3.12.1 are installed.
- Android command-line tools are installed at `/opt/homebrew/share/android-commandlinetools` with Android SDK platforms 35 and 36, platform-tools, Build-Tools 36.0.0, NDK 28.2.13676358, and CMake 3.22.1.
- Flutter is configured to use Homebrew OpenJDK 17.
- Xcode 26.5 is installed; `xcode-select -p` points to `/Applications/Xcode.app/Contents/Developer`. The app uses Flutter SwiftPM for iOS plugins; do not re-add `ios/Podfile` unless a new dependency requires it.
- Run app checks from `mobile_app/dosey_app/`: `dart format .`, `dart run build_runner build`, `git diff --exit-code -- lib/core/storage/dosey_database.g.dart`, `flutter analyze`, `flutter test`, `flutter build apk --debug`, `flutter build ios --debug --no-codesign`, and `git diff --check`.
- After Drift schema changes, run `dart run build_runner build`.

## Repo layout

- `firmware/`: Arduino/PlatformIO C++ examples first, then shared modules.
- `mobile_app/dosey_app/`: Flutter app; wrap BLE, notifications, auth, database, and permissions behind app-owned interfaces.
- `mechanical/`: Daviky carousel measurements, LEGO servo mount/body notes, chute/cup tests, assembly notes.
- `docs/`: `wiring.md`, `protocol.md`, `safety.md`, `test_plan.md`, `parts.md`, `build_log.md`, `decisions.md`, `mobile_stack.md`.
- `media/photos/` and `media/videos/`: build evidence and demos.

## Working rules

- Record wiring in `docs/wiring.md`; verify Grove module type before assuming I2C.
- Record command messages in `docs/protocol.md`; use ACK/NACK/status/event patterns.
- Record owned and missing parts in `docs/parts.md`; do not invent owned hardware.
- Check `docs/decisions.md` before changing architecture.
- Use XIAO ESP32-C6 and Grove Base for XIAO wording unless hardware changes.
- Keep Robot Mode Android-only; iOS stays Personal Mode only.
- Do not mark a phase complete unless its success criteria were met and logged.
- Keep README and `docs/` planning/status updates local unless the user explicitly asks to include documentation changes in the current branch or PR. Before pushing an app/code PR, verify the final diff excludes local planning docs unless docs are in scope.
- Do not commit or push unless the user explicitly asks; never push `AGENTS.md` or other AI/OpenCode instruction files unless explicitly asked.
- Never commit, push, or include Superpowers/AI workflow artifacts in main or PRs. Do not add `docs/superpowers/` specs or plans to the repo; if a workflow creates one locally, delete it or keep it ignored before the final diff.
- When an open PR is active and the user provides review findings, treat that as permission to verify, fix still-valid findings, validate, commit the intended code/test changes, push the branch, and update the PR. Do not include `AGENTS.md` in those commits unless explicitly asked.
- When writing or reviewing code, add concise comments for complicated or confusing logic, especially safety-sensitive state transitions. Keep comments efficient: explain why the code is non-obvious, not what obvious statements do.
- Make human-style PR messages and titles less AI. Before creating or editing a PR, use a real multiline body via a body file, `$'...'` shell quoting, or another method that preserves actual newlines. Never pass escaped `\n` text that can show up literally in GitHub.
