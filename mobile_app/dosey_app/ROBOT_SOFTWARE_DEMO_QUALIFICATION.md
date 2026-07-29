# Robot Software Demo Qualification Record

## Claim boundary

This record covers an Android Robot guest software prototype for local
medication scheduling and a simulator-backed fake-dose workflow. It does not
physically dispense and is not a medical device. Do not use real medication.
No physical dispense or controller movement may infer that a dose was taken.

This is automated and source-build qualification evidence, not physical Android
device qualification. The demo is not device-qualified or released. Physical
Android evidence remains pending.

## Provenance and observed build evidence

- Documentation baseline: `8581d2759785eb7d156cd4f2e3738bdf644f54e8`
  ([PR #76](https://github.com/SloppyBobbert/Dosey/pull/76) merge).
- Available Robot APK source: `06d544d0eddbf74ad0cd74699787ac049b4e3538`.
- Artifact: Robot debug APK, 202,579,247 bytes; SHA-256
  `e24bb844e3f9453e89b79352fbf02d7db000b8b9d1f06e175815220f9759ad94`.
- The APK is debug-signed and is not release-signed.

The commits between the APK source and the documentation baseline are PR #76
documentation and test changes only. This records that narrow comparison; it
does not establish equivalence to future commits or artifacts.

Historical local toolchain observed for the recorded run on 2026-07-29 PDT:
Flutter 3.44.1 stable, Dart 3.12.1, and framework revision
`924134a44c189315be2148659913dda1671cbe99` on macOS arm64. The current Mobile
CI baseline at this documentation base is [Flutter 3.44.6 stable](../../.github/workflows/mobile-ci.yml).

At the exact APK source, the observed automated evidence was:

- Full `flutter test --no-pub`: 1,109/1,109 passed, with only the known Drift
  multiple-database warnings.
- Full `flutter analyze --no-pub`: no issues.
- Offline Robot debug APK build: succeeded.

These are recorded observations, not a claim that a fresh setup is reproducible
without network access.

[PR #76](https://github.com/SloppyBobbert/Dosey/pull/76) backup hardening also
had 140/140 focused backup, reminder, local-database, and Settings tests pass
before commit; its
[Mobile CI run](https://github.com/SloppyBobbert/Dosey/actions/runs/30429880331)
later passed. Those unit and integration tests do not qualify Android
file-provider export/import or crash/power-loss behavior.

## Evidence matrix

| Area | Automated/source-build evidence | Boundary |
| --- | --- | --- |
| Robot guest and build-profile boundary | [Build profile source](lib/core/build/app_build_profile.dart), [build profile tests](test/core/build/app_build_profile_test.dart), and [app tests](test/widget_test.dart) cover fixed profile resolution and guest-local Robot behavior. | Not an installed-device result. |
| Simulator and Guided Trial | [Simulator gateway](lib/core/controller/simulated_controller_gateway.dart), [scenario tests](test/core/demo/demo_scenario_service_test.dart), and [Guided Trial tests](test/features/guided_trial/guided_trial_test.dart) cover happy, missed-dose, offline, reconnect, and failure paths. | Simulator events do not move hardware or dispense media. |
| Movement, visible, and taken state | [Dose action tests](test/features/doses/dose_action_service_test.dart) and [simulator scenario regressions](test/features/shell/simulator_scenario_regression_test.dart) support separate movement, visible, and taken states, including a duplicate taken action being ignored and inventory decrementing once. | Does not prove physical dose presence or ingestion. |
| Local persistence, reminders, and backup | [Local database tests](test/core/storage/local_database_test.dart), [reminder tests](test/core/reminders/reminder_schedule_service_test.dart), [backup service tests](test/core/backup/local_backup_service_test.dart), and [backup store tests](test/core/backup/local_backup_store_test.dart) cover local data, reminder scheduling logic, and backup rollback. The populated on-disk close/reopen case at `test/core/backup/local_backup_store_test.dart:203-232` proves current-format restore persistence. | Does not qualify OS notification delivery, Android file providers, or crash/power-loss durability. |
| Robot lifecycle, Back, screen-awake, notifications | [Robot shell tests](test/features/shell/dosey_shell_test.dart) and [notification tap tests](test/core/notifications/reminder_notification_tap_controller_test.dart) exercise the automated lifecycle, Back, display-awake, and in-app routing logic. | OEM lifecycle/display behavior and actual notification delivery are unverified. |
| Fixed WAV catalog | [Voice asset directory](assets/voice/) and [fixed phrase catalog tests](test/core/voice/fixed_phrase_catalog_test.dart) establish catalog paths used by the app. | Ownership and license provenance for the voice assets are not yet recorded. |
| APK artifact | The debug APK metadata above identifies the available artifact and its exact source commit. | It is debug-signed, not release-signed, and has not been installed or walked through on a physical device. |

[Demo host tests](test/core/demo/demo_mode_host_test.dart) and
[demo repository tests](test/core/demo/demo_data_repository_test.dart) cover the
separate Guided Trial data path. These workflows remain simulated and do not
imply physical actions or replace a physical production-database check.

## Deferred and not verified

- APK transfer/install and Moto G Play real-device walkthrough.
- Actual Android OS notification delivery, sound, tap routing, process restart,
  OEM lifecycle/display behavior, and pixel-level Maintenance repaint behavior.
- Android file-provider export/import and crash/power-loss durability.
- Physical-device BLE/XIAO validation of the identified APK and integrated
  external-hardware lifecycle; servo/carousel movement, fake-media dispensing,
  and cancellation/timeout/power-loss movement behavior.
- Appwrite/pairing/live staging.
- Voice asset ownership/license provenance.
- Release signing, versioning, tag, and GitHub Release.

## Pending physical evidence

1. Transfer and install the identified debug APK on the Moto G Play, then run a
   supervised Robot guest walkthrough using fake doses only.
2. Observe notifications, routing, process restart, Back behavior,
   screen-awake release, and Maintenance repaint on the device.
3. Exercise backup export/import through Android file providers and record
   restart and failure behavior.
4. Keep this qualification simulator-backed. Existing bare-XIAO bench evidence
   does not qualify this APK or the integrated carousel path. Do not attach real
   medication or infer a taken dose from movement.

Related format and controller boundaries are documented in
[the backup format](../../docs/local_backup_format.md) and
[the controller bench runbook](../../docs/controller_bench_runbook.md).
