# Safety

Dosey is an experimental prototype, not a medical-grade device.

Prototype tests must use candy, beads, dry beans, vitamins, or fake pills. Do not use real prescription medication during early testing.

## Core rules

- Do not give medical advice.
- Do not tell users to double dose.
- Do not imply that Dosey proves a medication was swallowed.
- Do not mark a dose taken because a command was sent, Bluetooth acknowledged, or the servo moved.
- Keep dispensed, visible, confirmed taken, skipped, missed, and error states separate.
- Make refill and loading steps clear enough that each carousel compartment receives the intended scheduled dose.
- Keep the LEGO shell, cup area, refill access, and debug panels serviceable and safe to open.

## Missed-dose wording

Use language like:

> This dose was missed. Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.

Do not write copy that tells the user to take an extra dose or change their medication routine.

## Prototype risks

- The carousel may jam, skip, roll backward, or misalign with the chute.
- Pills, candy, beads, or vitamins may bounce, stick, or miss the cup.
- The cup may be missing or placed incorrectly.
- The servo may jitter, reset the controller, or fail under load.
- Bluetooth may disconnect or the XIAO may stop responding.
- A user or caregiver may load the wrong dose into a slot.
- The app may know the phone is alive while the physical dispensing hardware is offline.

## Required safeguards for later builds

- Movement timeout and error reporting.
- Cancel or emergency stop behavior.
- Bluetooth acknowledgement and failure handling.
- Heartbeat/offline detection between the phone and XIAO.
- Manual user confirmation that the expected medication is visible.
- Separate user confirmation that the dose was taken.
- Refill/index correction flow when the carousel position changes.
