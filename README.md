# Dosey

[![Status](https://img.shields.io/badge/status-early%20prototype-orange)](#project-status)
[![Medical grade](https://img.shields.io/badge/medical--grade-no-red)](#safety)
[![Mobile](https://img.shields.io/badge/mobile-Flutter-02569B?logo=flutter&logoColor=white)](#mobile-app)
[![Local data](https://img.shields.io/badge/local%20data-Drift%20%2F%20SQLite-336791)](#mobile-app)
[![Controller](https://img.shields.io/badge/controller-ESP32--C6-333333)](#firmware)
[![Hardware](https://img.shields.io/badge/hardware-not%20dispensing%20yet-lightgrey)](#project-status)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)

Dosey is an early medication-reminder robot prototype. It pairs a phone app with a small ESP32 controller and a premade pill carousel so the robot can remind, react, and present a preloaded dose.

This is a prototype and research build. It is not a medical-grade device.

## At a glance

| Area | Current state |
| --- | --- |
| Mobile app | Flutter app with local reminders, settings, auth cache, dose log, and controller simulator |
| Local data | Drift/SQLite on the phone app only |
| Controller | XIAO ESP32-C6 planned; firmware not started yet |
| Mechanism | Premade carousel direction chosen; movement not proven yet |
| Cloud sync | Not selected or implemented |
| Safety status | Fake-pill testing only; not for real medication |

## Safety

Do not test Dosey with real prescription medication. Early tests must use candy, beads, dry beans, vitamins, or fake pills.

Dosey must not mark a dose as taken just because the servo moved. The app may log a dispense only after the controller reports success. Later versions should require drop or cup confirmation before treating a dose as delivered.

Known prototype risks:

- The carousel can jam, skip, or misalign.
- The app and controller can disconnect.
- A cup, lid, door, or dose sensor can be missing or wrong.
- A user can load the carousel incorrectly.
- Servo motion alone cannot prove a pill reached the user.

See [`docs/safety.md`](docs/safety.md) for the current safety notes.

## Current build direction

Dosey is built around three main systems:

1. **Mobile app**
   - Flutter/Dart app for Android and iOS
   - First test device: 2024 Moto G Play
   - Uses a local Drift/SQLite database for app settings, reminder schedules, cached auth state, and dose logs
   - Handles local reminder add/edit/delete controls, local logs, Google sign-in plumbing, permissions, and app-controller messaging
   - Supports Android robot phone mode, Android personal phone mode, and iOS personal phone mode only

2. **Controller**
   - Seeed Studio XIAO ESP32-C6 on the XIAO Expansion Board
   - Starts with Grove module bring-up examples
   - Later handles BLE command/status messages, buttons, feedback modules, and servo control

3. **Premade pill carousel**
   - Each compartment holds one preloaded dose
   - First actuator path: Grove servo pusher/ratchet for one-slot movement
   - Early fixtures can use LEGO, cardboard, tape, or temporary mounts before CAD work

## Hardware on hand

### Main electronics

- Seeed Studio XIAO ESP32-C6
- Seeed Studio XIAO Expansion Board
- Grove Shield for Raspberry Pi Pico
- Grove I2C Hub, 6-port x2
- Grove cables x7
- Male-to-male jumper wires x4

### Output modules

- Grove buzzer
- Grove vibration motor
- Grove LED pack
- WS2813 RGB LED strip
- Grove servo

### Input modules and sensors

- Grove dual button x2
- Grove mini PIR motion sensor
- Grove light sensor
- Grove temperature and humidity sensor
- Grove rotary angle sensor
- Grove 3-axis digital accelerometer
- Grove IR receiver
- 30-key mini controller

### Other hardware

- 2024 Moto G Play
- USB-C hub
- Premade pill carousel
- LEGO pieces for early mechanical mockups
- Assorted USB and power cables

Track owned and missing parts in [`docs/parts.md`](docs/parts.md). Do not assume unlisted hardware is available.

## Build order

The project should prove the mechanism before app polish or enclosure work.

1. Grove electronics bring-up: blink/serial, buttons, buzzer, vibration, LEDs, PIR, and servo sweep
2. Physical interaction demo with debounced buttons and feedback patterns
3. BLE command/status demo between Flutter app and XIAO, tested on Moto G Play first and then iPhone
4. Carousel inspection, measurement, and 10-cycle one-slot servo advance test
5. Chute/cup fake-pill dispense test
6. Integrated reminder-to-dispense-to-log demo
7. Reliability sensors and enclosure work after the mechanism works

Log progress in [`docs/build_log.md`](docs/build_log.md) and criteria in [`docs/test_plan.md`](docs/test_plan.md).

## Repository map

```text
Dosey/
├── README.md
├── firmware/              # Arduino/PlatformIO C++ examples for XIAO ESP32-C6
├── mobile_app/            # Flutter app workspace; app lives in mobile_app/dosey_app/
├── mechanical/            # Carousel measurements, mockups, assembly notes, later CAD/STL
├── docs/                  # Wiring, protocol, safety, tests, parts, decisions, logs
└── media/                 # Photos and videos from hardware tests
```

Useful docs:

| Doc | Use it for |
| --- | --- |
| [`docs/wiring.md`](docs/wiring.md) | Grove ports, XIAO pin map, power paths, shared grounds |
| [`docs/protocol.md`](docs/protocol.md) | BLE/serial command, ACK/NACK, status, and event messages |
| [`docs/mobile_stack.md`](docs/mobile_stack.md) | Flutter mobile architecture notes |
| [`docs/decisions.md`](docs/decisions.md) | Architecture and build-direction decisions |
| [`docs/test_plan.md`](docs/test_plan.md) | Bring-up checks, app checks, and hardware test criteria |

## Firmware

Firmware will start as small Arduino/PlatformIO C++ examples for the XIAO ESP32-C6. Bring up each Grove module on its own before combining modules into a controller firmware.

No firmware build command exists yet.

## Mobile app

The app is a Flutter project under `mobile_app/dosey_app/`. Android is the first test target because the Moto G Play is available, but the app architecture keeps iOS support in scope.

BLE, notifications, local storage, auth, and permissions should sit behind app-owned interfaces so early prototypes can change libraries without rewriting the app.

The local database uses Drift on SQLite. The phone app stores app settings, reminder schedules, cached local auth state, and dose log events locally; the ESP32 controller should only keep tiny controller state later, not a SQLite database. Cloud sync can come later after the local model is stable.

The app now has a plain five-tab shell: Today, Reminders, Controller, Log, and Settings. Google sign-in is wired through an app-owned auth interface with `google_sign_in`, but there is no Firebase, Supabase, or cloud session backend yet.

Device roles are intentionally platform-limited:

- Android robot phone: the Android phone lives inside the robot and can host robot-control behavior.
- Android personal phone: a personal Android phone can receive notifications and use the app.
- iOS personal phone: iOS can receive notifications and use the app, but cannot be the robot's embedded phone.

Current local checks:

```sh
cd mobile_app/dosey_app
dart format .
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
# Run this after Drift schema changes:
dart run build_runner build
```

Local setup so far:

- Flutter 3.44.1 stable and Dart 3.12.1 are installed with Homebrew.
- Android command-line tools, Android SDK platforms 35 and 36, platform-tools, build-tools 36.0.0, NDK 28.2.13676358, CMake 3.22.1, and OpenJDK 17 are installed.
- Flutter is configured to use `/opt/homebrew/share/android-commandlinetools` and the Homebrew OpenJDK 17 install.
- CocoaPods 1.16.2 is installed for future iOS plugin work.
- Xcode 26.5 is selected at `/Applications/Xcode.app/Contents/Developer`; local no-codesign iOS debug builds run.

## Mechanical prototype

The first mechanism to test is a servo pusher:

1. The servo arm moves forward.
2. The arm advances the carousel one slot.
3. A physical stop or ratchet prevents rollback.
4. The servo returns to its starting position.
5. The next preloaded dose lines up with the chute or pickup area.

Use rough fixtures until repeatable one-slot movement works. Save measurements and test notes in `mechanical/` and `docs/build_log.md`.

## Project status

Early prototype. The repo now has a safety-first Flutter app shell, local reminder add/edit/delete controls, local settings/auth/dose-log storage, a controller simulator, Google sign-in plumbing, and local Android/iOS tooling. It still has no firmware, BLE implementation, cloud sync, or carousel movement test.

Near-term work:

- Test Grove modules on the XIAO Expansion Board.
- Record wiring and power paths.
- Draft the controller protocol.
- Build a servo sweep and one-slot carousel movement test.
- Draft the real BLE protocol before adding a BLE package.

## License

This repository currently uses the GNU General Public License v3. See [`LICENSE`](LICENSE).
