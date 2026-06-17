# Dosey docs

Use this folder for project notes that should stay with the repo. The Markdown files are the project source of truth; planning `.docx` files are reference input, not required repo artifacts.

| File | Purpose |
| --- | --- |
| [`wiring.md`](wiring.md) | XIAO model notes, Grove ports, power paths, servo power, and shared grounds |
| [`protocol.md`](protocol.md) | Bluetooth commands, acknowledgements, heartbeat, status, errors, and dose-event logging |
| [`safety.md`](safety.md) | Prototype limits, fake-pill testing, missed-dose wording, and dispense/taken separation |
| [`test_plan.md`](test_plan.md) | Build stages, mobile checks, servo/carousel tests, Bluetooth tests, and failure simulations |
| [`parts.md`](parts.md) | Owned, planned, optional, and to-confirm parts |
| [`build_log.md`](build_log.md) | Dated build notes, failures, test evidence, and demos |
| [`decisions.md`](decisions.md) | Architecture and build decisions |
| [`mobile_stack.md`](mobile_stack.md) | Flutter app stack, Robot Mode, Personal Mode, and local-first architecture notes |

Keep safety, wiring, protocol, and test notes current as the build changes. Do not mark a hardware phase complete unless its criteria are met and logged.
