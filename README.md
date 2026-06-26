# Dosey

[![Status](https://img.shields.io/badge/status-early%20prototype-orange)](#project-status)
[![Medical grade](https://img.shields.io/badge/medical--grade-no-red)](#safety)
[![Mobile](https://img.shields.io/badge/mobile-Flutter-02569B?logo=flutter&logoColor=white)](#mobile-app)
[![Local data](https://img.shields.io/badge/local%20data-Drift%20%2F%20SQLite-336791)](#mobile-app)
[![Mobile CI](https://github.com/SloppyBobbert/Dosey/actions/workflows/mobile-ci.yml/badge.svg)](https://github.com/SloppyBobbert/Dosey/actions/workflows/mobile-ci.yml)
[![Hardware](https://img.shields.io/badge/hardware-not%20dispensing%20yet-lightgrey)](#project-status)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)

Dosey is a low-cost, open-source medication-dispensing companion robot prototype. It combines a premade Daviky pill carousel, a mounted Android phone face, a Seeed Studio XIAO ESP32-C6 with the Grove Base for XIAO, a servo-driven one-slot mechanism, and a fully LEGO shell direction.

This is a prototype and research build. It is not a medical-grade device.

## At a glance

| Area | Current direction |
| --- | --- |
| Medication storage | Premade Daviky pill carousel; each compartment holds one scheduled dose |
| Robot phone | Horizontal Android phone, first tested on the 2024 Moto G Play |
| Personal app | Flutter app for Android and iOS personal phones |
| Controller | Seeed Studio XIAO ESP32-C6 controller |
| Expansion hardware | Seeed Studio Grove Base for XIAO, with Grove ports for servo, PIR, and feedback modules |
| Mechanism | Grove servo pusher with a ratchet or physical stop; basic servo movement is confirmed |
| Shell | Fully LEGO body around the carousel, phone, electronics, cup opening, and service panels |
| App data | Drift/SQLite on the phone only; no backend or cloud sync yet |
| App shell | Today, Prescriptions, Schedule, Carousel, Controller, Log, Settings, and profile menu |
| Safety status | Fake-pill testing only; not for real medication |

## Safety

Do not test Dosey with real prescription medication. Early tests must use candy, beads, dry beans, vitamins, or fake pills.

Dosey must not mark a dose as taken because the servo moved. The app should separately track command sent, servo completed, dose visible, dose confirmed taken, skipped, missed, and error states. For missed doses, Dosey must not tell the user to double dose; it should tell the user to follow prescription instructions or ask a caregiver, pharmacist, or doctor.

Known prototype risks:

- The carousel can jam, skip, roll backward, or misalign with the chute.
- The cup can be missing or placed wrong.
- The app and XIAO controller can disconnect.
- The XIAO, Grove board, or servo power can reset or fail.
- A user or caregiver can load the carousel incorrectly.
- Dispensed does not mean visible, and visible does not mean taken.

See [`docs/safety.md`](docs/safety.md) for the current safety notes.

## Current build direction

Dosey is built around four main systems:

1. **Daviky carousel and dispense path**
   - Use the premade Daviky carousel, chute, cup, and stand as the medication storage and presentation base.
   - Do not count individual pills. Each carousel compartment should hold one scheduled dose.
   - Use a Grove servo pusher to advance one slot at a time.
   - Add a ratchet or physical stop so the carousel does not roll backward.

2. **Phone app**
   - The mounted Android phone is the robot face, speaker, reminder system, and main computer.
   - Robot Mode runs only on Android.
   - Personal Mode runs on Android and iOS phones for patient or caregiver use.
   - The phone handles schedules, medication data, refill logic, dose history, PIN rules, caregiver logic, UI, reminders, Bluetooth commands, and future cloud or voice features.

3. **XIAO and Grove controller**
   - The controller handles direct hardware only: servo movement, PIR, LEDs, buzzer/vibration, buttons, sensor readings, status, and Bluetooth messages.
   - The confirmed controller is the Seeed Studio XIAO ESP32-C6.
   - The confirmed Grove base is the Seeed Studio Grove Base for XIAO. Older XIAO Expansion Board references are historical.

4. **LEGO shell**
   - The shell direction is now fully LEGO, not a temporary placeholder before 3D printing.
   - The body should hold the carousel, phone, cup opening, servo, wiring, and electronics while keeping refill and debugging access clear.

## Hardware on hand and to confirm

Track owned and missing parts in [`docs/parts.md`](docs/parts.md). Do not assume unlisted hardware is available.

Current plan-critical hardware:

- Premade Daviky pill carousel with chute, cup, stand, and refill access.
- Horizontal Android phone, currently the 2024 Moto G Play or similar.
- Seeed Studio XIAO ESP32-C6 controller.
- Seeed Studio Grove Base for XIAO.
- Grove servo, with basic movement confirmed.
- Grove Mini PIR motion sensor.
- Grove cables, LEDs or LED strip, optional buzzer/vibration/buttons/sensors.
- Multi-port USB charger with separate phone and controller power paths.
- LEGO bricks for the complete shell.

## Build stages

The project should now focus on the servo/carousel rig while app MVP work continues in parallel.

1. **Hardware confirmed** — ESP32-C6, Grove Base for XIAO, and basic servo movement are confirmed. Continue one-module checks for PIR, buttons, LEDs, buzzer/vibration, and sensors.
2. **Servo and carousel rig** — Next major build. Advance the Daviky carousel one slot repeatably, prevent rollback, and align the slot with the chute/cup.
3. **Bluetooth control** — Make the phone command the XIAO wirelessly with acknowledgements and status events.
4. **Basic app MVP** — Build Robot Mode with schedule, loading guide, dispense, refill, history, hardware test, and local safety flows.
5. **LEGO body integration** — Turn the working rig into a cute, stable, serviceable LEGO robot body.
6. **Reliability features** — Add heartbeat/offline warnings, refill warnings, missed-dose logic, PIN, error recovery, and index correction.
7. **Advanced interaction** — Future Piper voices, voice commands, local command recognition, AI experiments, caregiver summaries, video shortcut, and face recognition.

Log progress in [`docs/build_log.md`](docs/build_log.md) and criteria in [`docs/test_plan.md`](docs/test_plan.md).

## Repository map

```text
Dosey/
├── README.md
├── firmware/              # Arduino/PlatformIO C++ examples for XIAO and Grove hardware
├── mobile_app/            # Flutter app workspace; app lives in mobile_app/dosey_app/
├── mechanical/            # Daviky carousel, LEGO shell, servo rig, measurements, assembly notes
├── docs/                  # Wiring, protocol, safety, tests, parts, decisions, logs
└── media/                 # Photos and videos from hardware tests
```

Useful docs:

| Doc | Use it for |
| --- | --- |
| [`docs/wiring.md`](docs/wiring.md) | Grove ports, XIAO pin map, power paths, shared grounds |
| [`docs/protocol.md`](docs/protocol.md) | Bluetooth command, acknowledgement, heartbeat, status, and dose-event messages |
| [`docs/mobile_stack.md`](docs/mobile_stack.md) | Robot Mode, Personal Mode, local data, and mobile architecture notes |
| [`docs/decisions.md`](docs/decisions.md) | Architecture and build-direction decisions |
| [`docs/test_plan.md`](docs/test_plan.md) | Stage criteria, mobile checks, hardware tests, and failure simulations |
| [`docs/parts.md`](docs/parts.md) | Owned, planned, and to-confirm parts |

## Firmware

Firmware will start as small Arduino/PlatformIO C++ examples for the XIAO and Grove modules. Bring up each module on its own before combining modules into controller firmware.

The controller should stay simple. It should handle direct hardware actions, heartbeat/status replies, ACK/NACK events, and error codes. It should not handle medication names, schedules, PIN logic, caregiver logic, voice, AI, or medical advice.

No firmware build command exists yet.

## Mobile app

The app is a Flutter project under `mobile_app/dosey_app/`. Android is the practical platform for Robot Mode because the phone lives inside Dosey; iOS remains supported for Personal Mode.

The current app has a seven-section shell: Today, Prescriptions, Schedule, Carousel, Controller, Log, and Settings, with a top-right profile menu. It includes safety acknowledgement storage, local prescription and schedule profile management, Daviky carousel loading assignments, local Drift/SQLite storage, a controller simulator, Google and Apple sign-in plumbing, and app-owned interfaces for controller communication, reminders, permissions, auth, notifications, and dose logging.

BLE, notifications, local storage, auth, and permissions sit behind app-owned interfaces so early prototypes can change libraries without rewriting the app. The current background foundation package set is:

- `flutter_blue_plus` for BLE foundation only; the real controller protocol is still incomplete.
- `connectivity_plus` for advisory connectivity and Wi-Fi status only; this is not Wi-Fi provisioning.
- `google_sign_in` plus a native iOS Apple sign-in bridge for Google/Apple-only auth.
- `flutter_local_notifications` for local reminder notifications and sounds.
- `permission_handler` for runtime permissions.

The app should grow toward two modes:

- **Robot Mode:** mounted Android phone face, reminders, dispense UI, hardware test screen, Bluetooth connection, refill status, dose history, sounds/TTS, and full-screen or kiosk-style behavior when practical.
- **Personal Mode:** patient or caregiver phone for notifications, missed dose/refill alerts, dose history, and schedule editing when permissions allow.

Reminder notification channel and sound IDs are intended to stay stable once chosen. Actual custom sound assets may still need platform provisioning where required.

Device roles are intentionally platform-limited:

- Android robot phone: the Android phone lives inside the robot and can host robot-control behavior.
- Android personal phone: a personal Android phone can receive notifications and use the app.
- iOS personal phone: iOS can receive notifications and use the app, but cannot be the robot's embedded phone.

Current local checks:

```sh
cd mobile_app/dosey_app
dart format .
dart run build_runner build
git diff --exit-code -- lib/core/storage/dosey_database.g.dart
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
git diff --check
```

Pull requests also run Mobile CI through GitHub Actions. The workflow checks committed whitespace, generated Drift code, formatting, analyzer output, tests, and an Android debug APK build on Ubuntu. iOS builds stay local for now because they require macOS runners.

## Mechanical prototype

The first mechanism to build is a servo pusher for the Daviky carousel:

1. The servo arm swings forward.
2. The arm advances the carousel one slot.
3. A ratchet or physical stop prevents rollback.
4. The servo returns to its starting position.
5. The next preloaded dose aligns with the Daviky chute and cup.

The servo has already been tested as strong enough for the current mechanism, so the main work is repeatable mounting, indexing, rollback prevention, and cup/chute alignment. Keep the LEGO shell serviceable and do not hide the mechanism before the one-slot movement test passes repeatedly.

## Project status

Early prototype. The repo has a safety-first Flutter app shell, local prescription and schedule controls, Daviky carousel loading and dispense workflow scaffolding, local settings/auth/dose-log storage, background package foundations for BLE/connectivity/auth/notifications/permissions, a controller simulator, Google and Apple sign-in plumbing, and local Android/iOS tooling. It still has no firmware, completed BLE protocol, hardware heartbeat, cloud sync, push notifications, or proven Daviky carousel movement.

Near-term work:

- Record the ESP32-C6 and Grove Base wiring, power paths, and servo power behavior.
- Build the Stage 2 servo/carousel rig and run repeated one-slot tests.
- Draft and test the Bluetooth command/status/heartbeat protocol.
- Expand Robot Mode around loading, dispense confirmation, refill tracking, and hardware tests.
- Integrate the working rig into a fully LEGO shell only after movement is repeatable.

## License

This repository currently uses the GNU General Public License v3. See [`LICENSE`](LICENSE).
