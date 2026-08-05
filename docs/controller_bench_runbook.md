# Controller Bench Runbook

Use this sequence to inspect the safe-default XIAO ESP32-C6 controller build
before connecting the Grove Base, Grove Servo, or any Grove module. It records
bench observations only; it does not qualify physical hardware or authorize
real medication testing.

## Preconditions

- Use candy, beads, dry beans, vitamins, or fake pills only in later mechanical tests.
- Disconnect the Grove Base, servo, battery pads, and every external wire.
- Confirm `firmware/include/hardware_config.local.h` does not exist.
- Build `controller_baseline` for normal checks or `controller_debug` only when USB diagnostics are needed.
- Use the command form `D1 CMD <command-id> <command>`; valid-command responses
  use the matching command ID, except that `CANCEL` reports
  `COMMAND_RECEIVED` with the cancel request ID and
  `MOVEMENT_CANCELLED_UNRESOLVED` with the interrupted movement ID. The
  unsolicited `D1 EVT pir WAKE_FACE` uses `pir`.
  Malformed or oversized input without a trusted ID may use `none`.
- Stop immediately for heat, smell, repeated resets, malformed output, connection instability, or unexpected movement.

## Safe-default identity

Connect through the app's Controller screen and run these Bench commands in
order. The command IDs vary; the event codes and order must match.

`DEVICE_INFO`:

```text
COMMAND_RECEIVED
DEVICE_INFO_OK
FIRMWARE_DOSEY_CONTROLLER
PROTOCOL_D1
BOARD_XIAO_ESP32_C6_GROVE_BASE
BUILD_BASELINE
```

The final event is `BUILD_DEBUG` when `controller_debug` is flashed.

`CONFIG_STATUS`:

```text
COMMAND_RECEIVED
CONFIG_STATUS_OK
SERVO_DISABLED
PIR_DISABLED
I2C_DISABLED
BUTTON_DISABLED
GROVE_DIAGNOSTICS_DISABLED
GROVE_BASE_D8_SERVO_PROFILE
```

Do not continue if any external path reports enabled in a committed build.

`SAFETY_STATUS`:

```text
COMMAND_RECEIVED
SAFETY_STATUS_OK
MOVEMENT_TIMEOUT_MS_2500
SERVO_PULSE_US_1000_2000
SERVO_ANGLES_DEG_90_100
DISPENSE_NEXT_DISABLED
```

These events report compiled values. They do not prove physical timeout,
travel, power, alignment, or jam behavior.

The safe-default `STATUS` transcript must end in `MOVEMENT_IDLE`; its earlier
events are `COMMAND_RECEIVED`, `STATUS_OK`, `SERVO_UNCONFIGURED`,
`PIR_UNCONFIGURED`, `DEBUG_UNAVAILABLE`, and `DEBUG_OFF` for the baseline
build. `HEARTBEAT` returns `COMMAND_RECEIVED` then `HEARTBEAT_OK`.

## Debug Build

Use this only with `controller_debug` and an open USB serial monitor at 115200
baud. Debug state starts off after every reboot and is not persisted.

1. Run `DEBUG_ON` from the app and confirm the command ends with `DEBUG_ON`.
2. Confirm USB serial prints the compiled configuration snapshot and then mirrors complete RX/TX protocol lines.
3. Run `STATUS`, `DEVICE_INFO`, `CONFIG_STATUS`, and `SAFETY_STATUS` again.
4. Confirm BLE command history contains only normal D1 events, not `DEBUG RX` or `DEBUG TX` text.
5. Run `DEBUG_OFF` and confirm the command ends with `DEBUG_OFF` before USB mirroring stops.

The baseline build must reject both debug commands with `COMMAND_DISABLED`.

## Movement Lockout

With external hardware still disconnected:

- `SERVO_TEST` and `DISPENSE_TEST` must return `CONFIGURATION_REQUIRED`.
- `DISPENSE_NEXT` must return `COMMAND_DISABLED`.
- No command may attach PWM or produce movement.
- A completed command session is controller evidence only. It never marks a dose visible, correct, or taken and never changes inventory.

`CANCEL` returns `NACK … NOT_MOVING` while this lockout is in effect. There is
no D1 `EMERGENCY_STOP` command. On an active configured movement, `CANCEL`
reports the interrupted command as `MOVEMENT_CANCELLED_UNRESOLVED`; a 2.5-second
deadline reports `MOVEMENT_TIMEOUT`. A disconnect stops active movement without
a completion event. These are source and native-test semantics, not physical
qualification evidence.

## Review boundary

The phone owns dose state and inventory. It changes inventory only after
explicit Taken confirmation. Treat a jam, ambiguous movement, cup/lid fault,
power interruption, timeout, cancellation, or disconnect as review-required;
do not infer a visible, correct, or Taken dose from a controller event.

Record observed radio and hardware behavior separately from automated build and
host-test results. Physical validation starts only after connector orientation,
power, and one-module-at-a-time wiring checks are complete.
