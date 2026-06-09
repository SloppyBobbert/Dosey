# Dosey

[![Status](https://img.shields.io/badge/status-early%20prototype-orange)](#project-status)
[![Medical grade](https://img.shields.io/badge/medical--grade-no-red)](#safety)
[![Mobile](https://img.shields.io/badge/mobile-Flutter-02569B?logo=flutter&logoColor=white)](#mobile-app)
[![Controller](https://img.shields.io/badge/controller-ESP32--C6-333333)](#firmware)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)

Dosey is an early medication-reminder robot prototype. It pairs a phone app with a small ESP32 controller and a premade pill carousel so the robot can remind, react, and present a preloaded dose.

This is a prototype and research build. It is not a medical-grade device.

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
   - Handles reminders, schedule UI, local logs, permissions, and app-controller messaging

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

- [`docs/wiring.md`](docs/wiring.md) — Grove ports, XIAO pin map, power paths, shared grounds
- [`docs/protocol.md`](docs/protocol.md) — BLE/serial command, ACK/NACK, status, and event messages
- [`docs/mobile_stack.md`](docs/mobile_stack.md) — Flutter mobile architecture notes
- [`docs/decisions.md`](docs/decisions.md) — architecture and build-direction decisions

## Firmware

Firmware will start as small Arduino/PlatformIO C++ examples for the XIAO ESP32-C6. Bring up each Grove module on its own before combining modules into a controller firmware.

No firmware build command exists yet.

## Mobile app

The app is a Flutter project under `mobile_app/dosey_app/`. Android is the first test target because the Moto G Play is available, but the app architecture keeps iOS support in scope.

BLE, notifications, local storage, and permissions should sit behind app-owned interfaces so early prototypes can change libraries without rewriting the app.

Current local checks:

```sh
cd mobile_app/dosey_app
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

Local setup so far:

- Flutter 3.44.1 stable and Dart 3.12.1 are installed with Homebrew.
- Android command-line tools, Android SDK 36, platform-tools, build-tools 36.0.0, NDK 28.2.13676358, CMake 3.22.1, and OpenJDK 17 are installed.
- Flutter is configured to use `/opt/homebrew/share/android-commandlinetools` and the Homebrew OpenJDK 17 install.
- CocoaPods 1.16.2 is installed for future iOS plugin work.
- Full Xcode is still required before iOS builds can run.

## Mechanical prototype

The first mechanism to test is a servo pusher:

1. The servo arm moves forward.
2. The arm advances the carousel one slot.
3. A physical stop or ratchet prevents rollback.
4. The servo returns to its starting position.
5. The next preloaded dose lines up with the chute or pickup area.

Use rough fixtures until repeatable one-slot movement works. Save measurements and test notes in `mechanical/` and `docs/build_log.md`.

## Project status

Early prototype. The repo now has a safety-first Flutter app shell and local Android tooling, but no firmware, BLE implementation, or carousel movement test yet.

Near-term work:

- Test Grove modules on the XIAO Expansion Board.
- Record wiring and power paths.
- Draft the controller protocol.
- Build a servo sweep and one-slot carousel movement test.
- Connect the Flutter app to a controller simulator before real BLE hardware tests.

## License

This repository currently uses the GNU General Public License v3. See [`LICENSE`](LICENSE).
