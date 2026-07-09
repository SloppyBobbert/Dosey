# Mechanical

Daviky carousel measurements, servo rig notes, LEGO shell notes, assembly photos, and test evidence.

## Current direction

Dosey uses a premade Daviky pill carousel as the dose storage and dispense base. Each compartment holds one scheduled dose. Dosey does not count individual pills.

The shell direction is now fully LEGO. The LEGO body should hold the carousel, horizontal phone face, cup opening, servo, wiring, and electronics while keeping refill and debugging access clear.

## First mechanism

The first mechanism to build is a servo pusher:

1. The servo arm swings forward.
2. The arm advances the Daviky carousel one slot.
3. A ratchet or physical stop prevents rollback.
4. The servo arm returns.
5. The next dose aligns with the Daviky chute and cup.

The servo has already tested strong enough for the current mechanism. The next mechanical problem is reliable mounting, alignment, one-slot indexing, rollback prevention, and repeated movement.

Use fake pills, candy, beads, dry beans, or vitamins only during these tests. Do not use real prescription medication in the prototype rig.

## LEGO shell goals

- Cute boxy robot body with friendly proportions.
- Horizontal phone screen on the front.
- Clear lower front cup opening.
- Easy Daviky carousel refill access.
- Easy XIAO and Grove electronics access.
- Removable panels for debugging and repair.
- Stable base.
- Controlled cable routing.
- Polished front and sides; simpler back is acceptable for the first prototype.

The LEGO shell must not block the carousel, cup, phone charging cable, controller USB-C cable, or servo arm.

## Stage 2 success criteria

- Servo advances one slot.
- Carousel does not roll backward.
- Slot aligns with the chute and cup.
- Movement works repeatedly over at least 10 cycles.
- Failures and fixes are logged in `../docs/build_log.md`.

Record measurements, test photos, and repeatability notes before enclosing the rig in the LEGO shell.

Do not hide the mechanism inside a polished shell until the repeatable one-slot movement test passes.
