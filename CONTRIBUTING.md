# Contributing to Dosey

Dosey is an early prototype, not a medical-grade device. Start with the
[project status and safety guidance](README.md#safety), then work in the area
you are changing:

- [Mobile app](mobile_app/dosey_app/README.md): run the Flutter checks listed
  in the root README's [mobile section](README.md#mobile-app). Robot Mode is
  Android-only; Personal Mode supports Android and iOS.
- [Firmware](firmware/README.md): follow the pinned setup, host tests, build
  commands, and physical safety gates.
- [Appwrite backend](backend/appwrite/README.md): run its tests, typecheck,
  and build.
- [Controller protocol](docs/protocol.md) and
  [bench runbook](docs/controller_bench_runbook.md): read these before changing
  controller commands, movement behavior, or physical test procedures.

## Safety and data boundaries

- Test with candy, beads, dry beans, vitamins, or other fake pills only—never
  prescription medication.
- Do not treat movement, a controller event, or a visible dose as proof that a
  dose was taken. Stop testing on a jam, unexpected movement, reset,
  disconnect, heat, or power fault.
- The phone owns medication, schedule, dose, inventory, and caregiver data.
  Medication data stays local; the controller is hardware-only.
- Do not claim physical movement, BLE, or integrated hardware validation unless
  it was actually performed and documented.

## Scope and pull requests

Keep changes focused and avoid unrelated cleanup. Do not add secrets or real
medication or patient data. Describe the change, link relevant evidence, list
the checks you ran, and state any safety, local-data, pairing, or deployment
effects. Use the pull request template and call out checks that do not apply.

## Dependencies and review ownership

Keep dependency updates targeted and locked. Update dependencies for security,
compatibility, required fixes, or deliberate maintenance; include the rationale
and relevant validation. Avoid drive-by mass updates or toolchain changes.

Add CODEOWNERS only after ownership boundaries are stable and a meaningful
required-review policy can be maintained. Until then, keep review expectations
in the pull request and involve the people responsible for the affected area.
