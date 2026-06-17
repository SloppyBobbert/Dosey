# Wiring

Record the XIAO pin map, Grove ports, power paths, and shared grounds here.

Do not assume a Grove module is I2C just because it uses a Grove cable; verify the exact module type first.

## Current wiring direction

- Confirm the final XIAO board model before writing a final pin map. Current repo notes reference XIAO ESP32-C6, while older plan notes mention XIAO ESP32S3.
- Use a Grove expansion board/shield with enough ports as the current direction.
- Treat the old XIAO Expansion Board as an earlier reference until hardware testing confirms whether it remains useful.
- Test one Grove module at a time before combining modules.

## Power plan

- Use separate USB power lines so the phone and controller stay stable.
- Port 1 powers the Android phone through its normal charging cable.
- Port 2 powers the XIAO and Grove expansion board/shield through USB-C.
- The phone does not need a physical data cable to the XIAO; it charges normally and talks to the XIAO over Bluetooth.
- The servo can run through the Grove board only if stable.
- If the servo causes resets, disconnects, or jitter, use separate regulated 5 V servo power and connect grounds together.
- Motors must not be powered from the phone or directly through XIAO GPIO pins.

## Early Grove paths to record

- Grove Servo signal port and power source.
- Grove Mini PIR signal port.
- LED or LED strip port.
- Optional buzzer or vibration motor port.
- Optional button inputs.
- Any I2C sensor addresses found by scanner.

## Safety checks before each hardware test

- Unplug USB-C before adding or swapping a module.
- Plug in only the part being tested.
- Do not plug anything into the battery connector during early tests.
- Do not use SWD pins during early tests.
- Do not use the JST LiPo port during early tests.
