# Dosey

<p align="center">
  <img src="media/dosey-logo-01-classic.png" alt="Dosey robot face logo" width="160">
</p>

[![Status](https://img.shields.io/badge/status-early%20prototype-orange)](#project-status)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)

Dosey is an open-source medication-dispensing companion robot prototype that helps organize scheduled doses and reminders. It is not a medical device.

## Safety first

Use fake pills, candy, beads, dry beans, or vitamins only while testing this prototype. Follow prescription instructions; Dosey does not provide medical advice and must not be used to decide whether to take an extra dose.

Controller movement does not mean a dose was delivered, visible, correct, or Taken. If the app recognizes a missed-dose warning, it records only that the warning was seen; it does not change the dose state or supply.

> This dose was missed. Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.

Stop a physical test when there is a jam, unexpected movement, reset, disconnect, heat, or power fault. Dosey is not a medical device, and its physical hardware still needs qualification.

## How Dosey is meant to work

Dosey keeps a schedule on the phone and can present reminders through its app. The premade Daviky carousel has one compartment for each scheduled dose; Dosey does not count individual pills.

When a dose is due, the app can record a request to move the carousel, ask whether the expected dose is visible and correct, and then ask for an explicit **Taken** confirmation. These are separate steps. Supply changes only after an explicit Taken confirmation, never because the controller moved or because a missed-dose warning was acknowledged.

The app keeps local dose history and supply information. It can run as an optional mounted Android Robot Mode or as Personal Mode on a mobile device.

## What you can try today

The merged software foundation supports local use without cloud medication sync:

- Add local medications and schedules, then review dose actions in Today.
- Open Robot Face on an Android Robot build.
- Run Guided Trial with deterministic fake data, including simulated movement, missed-dose, and offline scenarios.
- Export and restore local backups from Settings.
- Use in-app Help and visit the [repository](https://github.com/SloppyBobbert/Dosey) or [issues](https://github.com/SloppyBobbert/Dosey/issues).
- Keep medication, schedules, dose history, and supply data on the device in Drift/SQLite.

## Modes and platforms

| Experience | Platform | Current note |
| --- | --- | --- |
| Personal Mode | Android and iOS mobile | The iOS implementation is retained but is not currently released or actively developed. iOS cannot be the phone mounted in the robot. |
| Robot Mode | Android only | Intended for the phone mounted in Dosey; it provides Robot Face and app-owned, soft navigation guardrails. |
| Appwrite pairing and caregiver features | Backend foundation | Legacy create/claim staging deployments remain active. The secure mounted-access and caregiver rollout is inactive; medication data is not cloud-synced. |

## Project status

Dosey has working software foundations for local medication and schedule management, Today actions, Robot Face, Guided Trial, local backup and restore, a controller simulator, and local-first storage.

The physical dispenser remains pending. The ESP32-C6 controller, Bluetooth lifecycle, servo power path, repeatable one-slot carousel movement, and integrated phone-to-hardware behavior require direct physical testing. Until that evidence exists, this repository should be treated as an experimental software and hardware prototype, not a public distribution or a reliable background reminder service.

### Roadmap

1. Qualify the local Android software experience on a real phone.
2. Test the controller and Daviky carousel with fake media, including faults and repeated one-slot movement.
3. Revisit the secure mounted-access and caregiver rollout only after mounted mobile compatibility, legacy-device inventory, a controlled staging rollout, and two-device validation.

## Explore or contribute

Start with the app, its documentation, or an open issue. Contributions that improve clarity, local safety behavior, testing, and reproducible hardware evidence are especially useful.

- Read the [app guide](mobile_app/dosey_app/README.md) for local setup and current app scope.
- Read the [protocol](docs/protocol.md), [controller bench runbook](docs/controller_bench_runbook.md), and [hardware validation record](firmware/HARDWARE_VALIDATION.md) before working with hardware.
- Review [open issues](https://github.com/SloppyBobbert/Dosey/issues) or browse the [repository](https://github.com/SloppyBobbert/Dosey).
- See the [local backup format](docs/local_backup_format.md) and [Robot software demo qualification record](mobile_app/dosey_app/ROBOT_SOFTWARE_DEMO_QUALIFICATION.md) for current evidence and limits.

## Repository map

```text
Dosey/
├── backend/appwrite/       # Server-side identity, ownership, and pairing foundations
├── firmware/               # XIAO bring-up programs and safe controller baseline
├── mobile_app/dosey_app/   # Flutter application
├── mechanical/             # Daviky carousel, servo, LEGO shell, and assembly notes
├── docs/                   # Protocols, test runbooks, and backup documentation
└── media/                  # Hardware photos and videos
```

## Technical details

### Architecture boundaries

The phone owns medication data, schedules, dose history, supply, user interface, reminders, and caregiver logic. Drift/SQLite is the authoritative local store for that information.

The Seeed Studio XIAO ESP32-C6 controller is hardware-only. It handles actions and reports from the servo, sensors, indicators, buttons, Bluetooth, and controller status. A controller success event is not proof of delivery, visibility, correctness, or Taken status.

The hardware plan uses a premade Daviky carousel, a Grove Base for XIAO, and a servo pusher. Never power motors from the phone or directly from XIAO pins; use a suitable motor power path with shared ground. Read the [mechanical and hardware notes](mechanical/README.md) before changing the physical build.

### Appwrite boundary

Appwrite supports identity, ownership or membership, and server-authorized pairing foundations. Flutter calls pairing functions and does not read pairing tables directly. Legacy create/claim staging deployments remain active. The secure mounted-access and caregiver rollout is inactive and must not be activated until mounted mobile compatibility, legacy-device inventory, a controlled staging rollout, and two-device validation are complete. Appwrite outages must not block the local Robot shell.

Medication schedules, dose state and history, supply, and related medication data remain local. There is no medication-data upload or cloud sync.

### Development commands

Run these from `mobile_app/dosey_app/`. The `.env` file is local and ignored; never commit it or put server secrets in it.

```sh
flutter pub get
dart format .
dart run build_runner build
git diff --exit-code -- lib/core/storage/dosey_database.g.dart
flutter analyze
flutter test
flutter run --flavor personal --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=personal --dart-define=DOSEY_RUNTIME_CAPABILITY=hardware-assisted --dart-define=CAREGIVER_SYNC_ENABLED=false
flutter run --flavor robot --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=robot --dart-define=DOSEY_RUNTIME_CAPABILITY=phone-only --dart-define=CAREGIVER_SYNC_ENABLED=false
flutter build apk --debug --flavor personal --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=personal --dart-define=DOSEY_RUNTIME_CAPABILITY=hardware-assisted --dart-define=CAREGIVER_SYNC_ENABLED=false
flutter build apk --debug --flavor robot --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=robot --dart-define=DOSEY_RUNTIME_CAPABILITY=phone-only --dart-define=CAREGIVER_SYNC_ENABLED=false
git diff --check
```

The retained iOS build is a preservation and compile-regression check, not release qualification:

```sh
flutter build ios --debug --no-codesign --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=personal
```

For firmware, run the safe-default controller build from `firmware/`. The command below uses a machine-specific PlatformIO path; see [`firmware/README.md`](firmware/README.md) for setup and the command for your environment:

```sh
/tmp/dosey-platformio/bin/pio run -e controller_baseline
```

Read [`firmware/README.md`](firmware/README.md) for setup, tests, upload commands, and physical safety gates.

### Verification limits

Mobile CI checks formatting, analysis, tests, generated Drift code, and debug builds. It does not qualify a release, background reminders, physical behavior, or production readiness. The committed controller firmware starts with external hardware paths disabled by default; see the [protocol](docs/protocol.md) for its current safe-default behavior and tested boundaries.

## License

Dosey is licensed under the [GNU General Public License v3.0](LICENSE).
