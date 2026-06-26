# Firmware

Arduino/PlatformIO C++ firmware for the Seeed Studio XIAO controller and Grove modules.

The confirmed controller is the Seeed Studio XIAO ESP32-C6. The confirmed Grove base is the Seeed Studio Grove Base for XIAO. Older ESP32S3 and XIAO Expansion Board references are historical notes.

## Firmware role

Keep firmware small and hardware-focused.

The XIAO should handle:

- Servo movement.
- PIR detection.
- LED status.
- Buzzer or vibration output.
- Basic button input.
- Basic sensor input.
- Carousel movement commands.
- Bluetooth communication.
- Heartbeat/status replies.
- Error codes for hardware faults.

The XIAO should not handle medication names, medication schedules, dose decisions, caregiver logic, PIN logic, voice generation, AI conversation, or medical advice.

## Bring-up order

Start with small Grove bring-up examples before combining modules into shared firmware:

1. Blink/serial sanity check.
2. Built-in buzzer and button checks if available on the chosen board/shield.
3. Grove LED, vibration motor, and external buzzer output checks.
4. Grove dual button and Mini PIR input checks.
5. Analog light sensor and rotary angle sensor checks.
6. I2C scanner for DHT20, accelerometer, and I2C hub.
7. Grove servo sweep.
8. Servo pusher test for one-slot Daviky carousel movement.
9. Bluetooth command/status demo with acknowledgement messages.
10. Heartbeat/offline behavior.

## Early protocol commands

Use `docs/protocol.md` as the source of truth. Early test commands include:

- `STATUS`
- `HEARTBEAT`
- `WAKE_FACE`
- `MOVE_SERVO`
- `DISPENSE_TEST`
- `DISPENSE_NEXT`
- `LED_TEST`
- `PIR_STATUS`

Report movement completion separately from dose visibility and dose taken confirmation.
