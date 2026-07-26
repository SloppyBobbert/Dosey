# Dosey

[![Status](https://img.shields.io/badge/status-early%20prototype-orange)](#project-status)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
[![Android](https://img.shields.io/badge/Android-3DDC84?logo=android&logoColor=white)](#mobile-app)
[![iOS](https://img.shields.io/badge/iOS-work%20in%20progress-lightgrey?logo=apple&logoColor=white)](#mobile-app)
[![Local data](https://img.shields.io/badge/local%20data-Drift%20%2F%20SQLite-336791)](#mobile-app)
[![ESP32-C6](https://img.shields.io/badge/ESP32--C6-E7352C?logo=espressif&logoColor=white)](#firmware)
[![Mobile CI](https://github.com/SloppyBobbert/Dosey/actions/workflows/mobile-ci.yml/badge.svg)](https://github.com/SloppyBobbert/Dosey/actions/workflows/mobile-ci.yml)
[![Medical grade](https://img.shields.io/badge/medical--grade-never-red)](#safety)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)

**Dosey is a low-cost, open-source medication-dispensing companion robot born from spite.**

Dosey is designed around being inexpensive, widely available, and with easily replaceable components. The current prototype uses:

- A premade, food safe-ish pill carousel
- Almost any inexpensive USB-C Android phone as its face and interface
- A Seeed Studio XIAO ESP32-C6 microcontroller
- Grove-compatible sensors and accessories
- Off-brand LEGO and other easy-to-find construction materials

The goal is to make Dosey as approachable and easy to assemble as possible, for people with little experience in electronics, programming, or robotics.

Although Dosey can be assembled by a caregiver, researcher, student, or hobbyist, I recommend building it with its intended user whenever possible. Seeing how Dosey works and becoming familiar with its components may make the device feel less intimidating and easier to trust, maintain, and repair.

Dosey uses an Android phone as its face, display, speaker, reminder system, and primary user interface. A small microcontroller handles the physical hardware, including sensors and the mechanism used to advance the pill carousel.

## Project Status

Dosey is an experimental prototype and research build originally developed during my 2026 summer student research project at California State University, Chico.

The project is intended to explore whether an inexpensive, expressive, and repairable companion robot can make medication routines more approachable than a standard pill organizer or phone alarm.

## At a glance

| Area | Current direction |
| --- | --- |
| Medication storage | Premade Daviky pill carousel; each compartment holds one scheduled dose |
| Robot phone | Horizontal Android phone, first tested on the 2024 Moto G Play |
| Personal app | Flutter app for Android and iOS personal phones |
| Controller | Seeed Studio XIAO ESP32-C6 controller |
| Expansion hardware | XIAO Expansion Board for the current no-solder servo and sensor layout; Grove Base for XIAO reserved for later |
| Mechanism | SG90 servo pusher with a ratchet or physical stop; the earlier Grove servo moved the carousel, but repeatability remains unverified |
| Shell | Fully LEGO body around the carousel, phone, electronics, cup opening, and service panels |
| App data | Drift/SQLite on the phone only; no backend or cloud sync yet |
| App shell | Today, Prescriptions, Schedule, Carousel, Controller, Log, and Settings, plus a face-first mounted experience in Android Robot Mode |
| Safety status | Fake-pill testing only; not for real medication |

## Safety

Known prototype risks:

- The carousel can jam, skip, roll backward, or misalign with the chute.
- Phone loses power/bluetooth/WIFI connection. 
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
   - Use an SG90 servo pusher to advance one slot at a time.
   - Add a ratchet or physical stop so the carousel does not roll backward.

2. **Phone app**
   - The mounted Android phone is the robot face, speaker, reminder system, and main computer.
   - Robot Mode runs only on Android.
   - Personal Mode runs on Android and iOS phones for patient or caregiver use.
   - Robot Mode returns to Robot Face on resume, after configurable inactivity, or when Back is pressed from another app tab. The screen stays awake only while Robot Face is active and the app is resumed.
   - The phone handles schedules, medication data, refill logic, dose history, PIN rules, caregiver logic, UI, reminders, Bluetooth commands, fixed prerecorded Robot Mode voice prompts, and future cloud, voice-command, or local AI features.

3. **XIAO and Grove controller**
   - The controller handles direct hardware only: servo movement, PIR, LEDs, buzzer/vibration, buttons, sensor readings, status, and Bluetooth messages.
   - The confirmed controller is the Seeed Studio XIAO ESP32-C6.
   - The current no-solder base is the XIAO Expansion Board. Its `D6/TX`, 5 V, and GND header accepts the owned SG90 servo without powering a motor from a 3.3 V Grove socket. Keep the Grove Base for XIAO intact and reserved for later.
   - The current module layout uses the SG90 on the `D6/TX` servo header, Mini PIR on `D0/A0`, DHT20 and LIS3DHTR on the two shared-bus I2C sockets, and the Expansion Board's onboard button, passive buzzer, OLED, and RTC. Keep the UART Grove socket empty because it shares D6 with the servo.

4. **LEGO shell**
   - The shell direction is now fully LEGO, not a temporary placeholder before 3D printing.
   - The body should hold the carousel, phone, cup opening, servo, wiring, and electronics while keeping refill and debugging access clear.

## Hardware on hand and to confirm

Track owned and missing parts in [`docs/parts.md`](docs/parts.md). Do not assume unlisted hardware is available.

Current plan-critical hardware:

- Premade Daviky pill carousel with chute, cup, stand, and refill access.
- Horizontal Android phone, currently the 2024 Moto G Play or similar.
- Seeed Studio XIAO ESP32-C6 controller.
- XIAO Expansion Board from the Seeed Studio XIAO Starter Kit.
- Seeed Studio Grove Base for XIAO, retained for later use.
- SG90 micro servo for the current 5 V carousel path.
- Grove servo, retained as previously tested hardware but not used in the current 3.3 V Grove layout.
- Grove Mini PIR motion sensor.
- Grove cables, LEDs or LED strip, optional buzzer/vibration/buttons/sensors.
- Multi-port USB charger with separate phone and controller power paths.
- LEGO bricks for the complete shell.

## Build stages

The project should now focus on the servo/carousel rig while app MVP work continues in parallel.

1. **Hardware selected** — ESP32-C6, Expansion Board, and the no-solder module layout are selected. Verify the SG90 header orientation, PIR, DHT20, LIS3DHTR, and onboard peripherals one at a time before combined or loaded testing.
2. **Servo and carousel rig** — Next major build. Advance the Daviky carousel one slot repeatably, prevent rollback, and align the slot with the chute/cup.
3. **Bluetooth control** — Finish the phone-to-XIAO command/status protocol with acknowledgements, heartbeat, and status events.
4. **Basic app MVP** — Continue Robot Mode with the face screen, schedule, loading guide, dispense, refill, history, hardware test, and local safety flows.
5. **LEGO body integration** — Turn the working rig into a cute, stable, serviceable LEGO robot body.
6. **Reliability features** — Add heartbeat/offline warnings, refill warnings, missed-dose logic, PIN, error recovery, and index correction.
7. **Advanced interaction** — Future voice commands, local command recognition, AI experiments, caregiver summaries, video shortcut, and face recognition.

Log progress in [`docs/build_log.md`](docs/build_log.md) and criteria in [`docs/test_plan.md`](docs/test_plan.md).

## Repository map

```text
Dosey/
├── README.md
├── firmware/              # XIAO bring-up programs and safe controller firmware baseline
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

Firmware includes small Arduino/PlatformIO C++ bring-up programs, a safe `controller_baseline` flash target, and a `controller_debug` variant with volatile USB-only diagnostics. Both run the versioned D1 protocol over BLE while every external hardware path remains disabled by default. Read-only device, configuration, and safety-limit commands support pre-hardware checks from the app's Controller bench card. Bring up each module on its own before enabling it in the controller configuration.

The controller should stay simple. It should handle direct hardware actions, heartbeat/status replies, ACK/NACK events, and error codes. It should not handle medication names, schedules, PIN logic, caregiver logic, voice, AI, or medical advice.

Build the safe-default controller image from `firmware/` with `/tmp/dosey-platformio/bin/pio run -e controller_baseline`. See [`firmware/README.md`](firmware/README.md) for pinned setup, tests, upload commands, and physical safety gates.

## Mobile app

The app is a Flutter project under `mobile_app/dosey_app/`. Android is the practical platform for Robot Mode because the phone lives inside Dosey; iOS remains supported for Personal Mode.

The app lives in `mobile_app/dosey_app/`. The current shell includes Today, Prescriptions, Schedule, Carousel, Controller, Log, and Settings for personal devices, plus Robot Face in Android Robot Mode. Mounted Robot Mode returns to Robot Face on resume and after a configurable 1, 2, 5, 10, or 15 minutes of inactivity, contains Back navigation inside the app, keeps the screen awake only while the face is active and the app is resumed, and routes local dose and shortage notification taps to the appropriate in-app surface. It includes local safety acknowledgement storage, prescription and schedule profile management, refill tracking, Daviky carousel loading, a controller simulator, Google and Apple sign-in plumbing, local Drift/SQLite storage, and app-owned interfaces for controller communication, reminders, permissions, auth, notifications, and dose logging.

BLE, notifications, local storage, auth, and permissions sit behind app-owned interfaces so early prototypes can change libraries without rewriting the app. The current background foundation package set is:

- `flutter_blue_plus` for BLE foundation only; the real controller protocol is still incomplete.
- `connectivity_plus` for advisory connectivity and Wi-Fi status only; this is not Wi-Fi provisioning.
- `google_sign_in` plus a native iOS Apple sign-in bridge for Google/Apple-only auth.
- `flutter_local_notifications` for local reminder notifications and sounds.
- `permission_handler` for runtime permissions.

The app should grow toward two modes:

- **Robot Mode:** mounted Android phone face, reminders, dispense UI, hardware test screen, controller-simulator and Bluetooth foundations, refill status, dose history, fixed prerecorded sounds, and soft in-app mounted-phone guardrails. The real Bluetooth controller protocol remains future work. It does not use Android device-owner, lock-task, or immersive kiosk provisioning.
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

The earlier Grove servo moved the actual carousel, which supports the pusher approach but does not validate the SG90 power path or repeated movement. The next work is SG90 testing, repeatable mounting, indexing, rollback prevention, and cup/chute alignment. Keep the LEGO shell serviceable and do not hide the mechanism before the one-slot movement test passes repeatedly.

## Project status

Early prototype. The repo has a safety-first Flutter app shell, mounted-phone Robot Mode guardrails, fixed prerecorded Robot Mode voice prompts, local prescription and schedule controls, local refill inventory tracking, Today dose-state logging that keeps controller movement separate from taken confirmation, skipped state, and inventory changes, Daviky carousel loading and dispense workflow scaffolding, local settings/auth/dose-log storage, background package foundations for BLE/connectivity/auth/notifications/permissions, a controller simulator, Google and Apple sign-in plumbing, local Android/iOS tooling, and a safe-default controller firmware baseline. It still has no physically validated integrated firmware, completed phone-to-hardware BLE lifecycle, cloud sync, push notifications, or proven repeatable Daviky carousel movement.

Near-term work:

- Verify the ESP32-C6 and Expansion Board wiring, pin assignments, and loaded servo power behavior.
- Build the Stage 2 servo/carousel rig and run repeated one-slot tests.
- Draft and test the Bluetooth command/status/heartbeat protocol against the simulator before hardware integration.
- Run mounted-phone manual QA on the Moto G Play, including inactivity return, notification routing, Back containment, screen-awake release, and role changes.
- Add screenshots or simulator scenario notes for the current app surfaces before a broader app polish PR.
- Integrate the working rig into a fully LEGO shell only after movement is repeatable.

## License

This repository currently uses the GNU General Public License v3. See [`LICENSE`](LICENSE).
