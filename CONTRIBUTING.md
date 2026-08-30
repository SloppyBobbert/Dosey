# Contributing to Dosey

Dosey is an early prototype, not a medical-grade device. Start with the
[project status and safety guidance](README.md#safety), then work in the area
you are changing:

- [Mobile app](mobile_app/dosey_app/README.md): run the Flutter checks listed
  in the root README's [mobile section](README.md#mobile-app). Active
  development supports Android Personal Mode and the web app on iOS, iPadOS,
  and computers. Native iOS Personal source is frozen historical source and is
  unsupported; iOS cannot host Robot Mode, which remains Android-only.
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
  dose was taken. Inventory changes only after explicit taken confirmation.
  Ambiguous movement, jams, cup/lid faults, power interruption, and disconnects
  must fail safe into needs-review or an equivalent state; stop testing on
  faults.
- Acknowledging a missed-dose warning is seen-only and must not change dose
  state or inventory. Never advise double dosing: `This dose was missed. Follow
  your prescription instructions or ask your caregiver, pharmacist, or doctor.`
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
