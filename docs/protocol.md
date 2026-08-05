# Protocol

Transport-independent command and status contract between the Flutter app and
XIAO controller. USB serial and BLE GATT implement the current bench
transports. Both preserve the same command IDs, response lines, and lifecycle
semantics.

The app must not log controller movement success without a controller completion event. It must not mark a dose Taken or change inventory until the user explicitly confirms Taken.

The Flutter app maps both simulator and BLE commands onto its local
command-session/event lifecycle instead of letting transport code bypass it.

## Responsibilities

The phone owns schedules, medication data, refill logic, inventory, dose history, PIN checks, caregiver logic, UI, reminders, and future voice/cloud features.

The XIAO owns direct hardware actions and reports: servo movement, PIR status, LEDs, buzzer/vibration, buttons, basic sensors, heartbeat/status, and error codes.

## Implemented USB and BLE bench protocol

`firmware/bringup/08_serial_protocol` implements a line-oriented USB serial demo
at 115200 baud. The `09_ble_protocol`, `controller_baseline`, and
`controller_debug` PlatformIO environments run the same canonical BLE source
over a single-client GATT service. These remain bring-up groundwork, not an
integrated dispenser protocol.

The BLE peripheral advertises as `Dosey-XIAO-C6` with service UUID
`8f3a1001-6f5b-4d4f-9c2a-5d6e7f801001`, RX/write characteristic
`8f3a1002-6f5b-4d4f-9c2a-5d6e7f801001`, and TX/notify characteristic
`8f3a1003-6f5b-4d4f-9c2a-5d6e7f801001`. Each side uses 20-byte chunks and
reassembles newline-delimited bounded messages. A disconnect stops active
movement without reporting completion, clears partial transport input, and
restarts advertising. These paths compile and are host-tested where transport
independent. Physical Android-to-bare-XIAO connection, safe-default status and
diagnostic commands, LED test, and disconnect indication have been observed.
That bench evidence does not qualify an APK, an integrated carousel, or
physical reconnect, power-loss, movement cancellation, timeout, or movement
behavior.

The framing, parsing, dispatch, status, timeout, cancellation, and exact output
transcripts are host-tested in `firmware/test/test_native`. Arduino-specific
code only adapts serial output, the onboard LED, PIR reads, and servo actions to
that protocol engine.

Requests use four ASCII fields:

```text
D1 CMD <command-id> <command>
```

- `D1` is the protocol version.
- Command IDs contain 1 to 24 ASCII letters, digits, hyphens, or underscores.
- A complete input line is limited to 96 characters, excluding the newline.
- Extra fields, unsupported versions, invalid IDs, unknown commands, and oversized lines are rejected.
- If malformed input has no trusted command ID, the firmware uses `none` in the NACK.
- The firmware ignores bytes after the 96-character limit until newline, emits `D1 NACK none LINE_TOO_LONG`, then accepts the next complete line normally.

Responses use one of these forms:

```text
D1 EVT <command-id> <event>
D1 NACK <command-id> <reason>
D1 ERROR <command-id> <error>
```

Responses to a command use that command's ID, except that `CANCEL` reports
`COMMAND_RECEIVED` with the cancel request ID and
`MOVEMENT_CANCELLED_UNRESOLVED` with the interrupted movement ID. The only
unsolicited event is `D1 EVT pir WAKE_FACE`; malformed or oversized input
without a trusted ID uses `none`.

## Canonical commands and responses

These are the only implemented D1 commands. Each response carries one event or
error code as its fourth field; D1 has no separate payload field.

| Command | Safe-default result | Configured-path result |
| --- | --- | --- |
| `STATUS` | Exact status transcript below | Reports configured inputs and active or idle movement |
| `HEARTBEAT` | `COMMAND_RECEIVED`, `HEARTBEAT_OK` | Same |
| `DEVICE_INFO` | Identity transcript below | Same |
| `CONFIG_STATUS` | Configuration transcript below | Reports enabled compiled paths |
| `SAFETY_STATUS` | Safety transcript below | Same compiled limits |
| `DEBUG_ON`, `DEBUG_OFF` | `NACK … COMMAND_DISABLED` in baseline | Debug build only: `COMMAND_RECEIVED`, then `DEBUG_ON` or `DEBUG_OFF` |
| `LED_TEST` | `COMMAND_RECEIVED`, `LED_TEST_STARTED`, `LED_TEST_DONE` | Same |
| `PIR_STATUS` | `NACK … CONFIGURATION_REQUIRED` | `COMMAND_RECEIVED`, then `PIR_MOTION` or `PIR_CLEAR` |
| `GROVE_DIAGNOSTICS` | `NACK … CONFIGURATION_REQUIRED` | Read-only diagnostic transcript ending in `DIAGNOSTICS_DONE` |
| `SERVO_TEST`, `DISPENSE_TEST` | `NACK … CONFIGURATION_REQUIRED` | Movement lifecycle below |
| `DISPENSE_NEXT` | `NACK … COMMAND_DISABLED` | Always disabled in current firmware |
| `CANCEL` | `NACK … NOT_MOVING` | Cancels the active movement as unresolved |

`WAKE_FACE` is the only unsolicited event: `D1 EVT pir WAKE_FACE` when a
configured PIR wake input activates. It uses the fixed ID `pir`.

The committed safe-default `STATUS` transcript is:

```text
D1 EVT <command-id> COMMAND_RECEIVED
D1 EVT <command-id> STATUS_OK
D1 EVT <command-id> SERVO_UNCONFIGURED
D1 EVT <command-id> PIR_UNCONFIGURED
D1 EVT <command-id> DEBUG_UNAVAILABLE
D1 EVT <command-id> DEBUG_OFF
D1 EVT <command-id> MOVEMENT_IDLE
```

`DEVICE_INFO` returns, in order: `COMMAND_RECEIVED`, `DEVICE_INFO_OK`,
`FIRMWARE_DOSEY_CONTROLLER`, `PROTOCOL_D1`,
`BOARD_XIAO_ESP32_C6_GROVE_BASE`, and `BUILD_BASELINE` or `BUILD_DEBUG`.
`CONFIG_STATUS` returns `COMMAND_RECEIVED`, `CONFIG_STATUS_OK`,
`SERVO_DISABLED` or `SERVO_ENABLED`, `PIR_DISABLED` or `PIR_ENABLED`,
`I2C_DISABLED` or `I2C_ENABLED`, `BUTTON_DISABLED` or `BUTTON_ENABLED`,
`GROVE_DIAGNOSTICS_DISABLED` or `GROVE_DIAGNOSTICS_ENABLED`, and
`GROVE_BASE_D8_SERVO_PROFILE`.

When paths are physically verified and locally enabled, configuration events
change to `SERVO_CONFIGURED` and `PIR_CONFIGURED`. Movement state is
`MOVEMENT_ACTIVE` only while one movement command owns the controller path;
otherwise it is `MOVEMENT_IDLE`.

The `controller_debug` build changes `DEBUG_UNAVAILABLE` to `DEBUG_AVAILABLE`.
Diagnostics still start `DEBUG_OFF` after every reboot. Toggling diagnostics
does not persist state, enable hardware, alter command outcomes, or send debug
text through BLE; it only mirrors transport and protocol activity to USB serial.

The committed `SAFETY_STATUS` transcript is:

```text
D1 EVT <command-id> COMMAND_RECEIVED
D1 EVT <command-id> SAFETY_STATUS_OK
D1 EVT <command-id> MOVEMENT_TIMEOUT_MS_2500
D1 EVT <command-id> SERVO_PULSE_US_1000_2000
D1 EVT <command-id> SERVO_ANGLES_DEG_90_100
D1 EVT <command-id> DISPENSE_NEXT_DISABLED
```

These values describe compiled safeguards only. They do not verify servo power,
mechanical travel, carousel alignment, BLE behavior, or physical fail-safe
operation. See `controller_bench_runbook.md` for the supervised check sequence.

When Grove diagnostics are enabled, `GROVE_DIAGNOSTICS` returns, in order,
`COMMAND_RECEIVED`, `GROVE_DIAGNOSTICS_OK`, `DIAGNOSTICS_BEGIN`,
`FIRMWARE_DOSEY_CONTROLLER`, `PROTOCOL_D1`,
`BOARD_XIAO_ESP32_C6_GROVE_BASE`, `BUILD_BASELINE` or `BUILD_DEBUG`, compiled
safety-limit values `MOVEMENT_TIMEOUT_MS_2500`, `SERVO_PULSE_US_1000_2000`,
`SERVO_ANGLES_DEG_90_100`, and `DISPENSE_NEXT_DISABLED`, then
`GROVE_BASE_D8_SERVO_PROFILE`, raw values
`PIR_RAW_<n>`, `LIGHT_RAW_<n>`, `BUTTON_1A_RAW_<n>`,
`BUTTON_1B_RAW_<n>`, `BUTTON_2A_RAW_<n>`, and `BUTTON_2B_RAW_<n>`, then
`DHT20_PRESENT` or `DHT20_NOT_FOUND`, `PIR_WAKE_ENABLED` or
`PIR_WAKE_DISABLED`, `SERVO_ENABLED` or `SERVO_DISABLED`,
`MOVEMENT_ACTIVE` or `MOVEMENT_IDLE`, `DHT20_READING_AWAITING_VALIDATION`,
`BUTTON_EVENTS_AWAITING_VALIDATION`, `PIR_CALIBRATION_REQUIRED`,
`BUZZER_TEST_AVAILABLE` or `BUZZER_TEST_DISABLED`, `LED_TEST_AVAILABLE`,
`RELIABILITY_SESSION_NOT_STARTED`, and `DIAGNOSTICS_DONE`.

After a servo and its power path are physically verified and explicitly enabled, `SERVO_TEST` and `DISPENSE_TEST` accept one movement at a time. Their lifecycle is `COMMAND_RECEIVED`, `MOVEMENT_STARTED`, then `SERVO_DONE` or an error. An overlapping command returns `BUSY`; reuse of the active ID returns `DUPLICATE_ACTIVE_ID`. `CANCEL` first replies `COMMAND_RECEIVED` with its own ID, then emits `MOVEMENT_CANCELLED_UNRESOLVED` with the interrupted movement ID. A deadline failure emits `MOVEMENT_TIMEOUT` with the movement ID.

`SERVO_ATTACH_FAILED` is emitted after command receipt but before
`MOVEMENT_STARTED` if the PWM path cannot attach. The firmware attempts to
detach the servo path after attach failure, cancellation, timeout, and normal
completion.

Other movement errors are `SERVO_WRITE_FAILED` and `SERVO_DETACH_FAILED`.
They are `ERROR` responses with the active movement ID. A detach failure may
follow cancellation, timeout, or another movement error. `SERVO_DONE` is
emitted only after a successful detach. A failed detach remains unresolved and
review-required.

`SERVO_DONE` means only that the commanded PWM sequence completed. It is not evidence of carousel advance, dose visibility, dose correctness, or dose intake.

There is no `EMERGENCY_STOP`, `STATUS_CHECK`, `MOVE_SERVO`, `LED_ON`,
`LED_OFF`, or `ERROR_CLEAR` command in D1. `CANCEL` is the only implemented
command-level stop request. A transport disconnect stops active movement
without emitting a completion event, clears partial transport input, and
restarts advertising. Power interruption has no controller response and is
physically ambiguous.

## Dose outcome boundary

The current firmware has no scheduled-dispense command flow: `DISPENSE_NEXT`
always returns `NACK … COMMAND_DISABLED`. `SERVO_TEST` and `DISPENSE_TEST` are
bench-only movement commands. Even if either returns `SERVO_DONE`, the phone
must still obtain explicit confirmation before recording a dose as Taken or
changing inventory.

The Flutter app maps BLE command IDs and D1 events into the same app-owned
lifecycle used by the simulator. A disconnect before `COMMAND_RECEIVED` is a
definite offline failure. A disconnect after receipt is interrupted and
physically ambiguous. `MOVEMENT_STARTED` remains separate from `SERVO_DONE`.
Manual `SERVO_TEST` and `DISPENSE_TEST` commands create command-session history
only; they must not write a real dose-log movement event. `DISPENSE_NEXT` stays
blocked by current firmware.

## Dose log states

Dose logs should distinguish:

- Dispense command sent.
- Command acknowledged.
- Servo movement completed.
- User confirmed dose visible.
- User confirmed dose taken.
- User snoozed reminder.
- User skipped dose.
- User marked already taken.
- User reported an error.
- Dose missed.
- Controller offline or unavailable.

Controller command sessions/events should also distinguish command sent, accepted/acknowledged when known, succeeded, failed, timed out, interrupted, and unresolved review-needed states. These are controller lifecycle states, not proof that a dose was taken.

Jams, ambiguous movement, cup/lid faults, power interruption, timeout,
cancellation, and disconnect require review. The controller has no jam, cup,
or lid sensor contract today; the phone must not convert their absence, a
movement event, or a reconnect into a dose outcome.

## Heartbeat and offline detection

The robot phone does not connect to the XIAO only when dispensing. In the
foreground Android Robot Mode session, after the user requests a connection,
the app verifies the controller with `HEARTBEAT` before enabling movement and
checks it every 10 seconds. Personal Mode, app backgrounding, deliberate
disconnect, and Demo Mode stop this supervision and do not scan or send
background BLE commands.

Current app policy:

- A BLE connection alone is not healthy. Only `HEARTBEAT_OK` moves controller health from verifying to online.
- One missed heartbeat, heartbeat timeout, or unexpected disconnect fails closed immediately and disables movement.
- A heartbeat due while a user command or cancel is active is deferred; it is not counted as missed and never overlaps that work.
- Eligible reconnect delays are 2, 5, 15, 30, then 60 seconds, capped at 60 seconds. The attempt count resets only after a successful heartbeat.
- Permission denial, unavailable Bluetooth, app backgrounding, Personal Mode, and deliberate disconnect suppress automatic retries.
- Recovery requires both a restored BLE connection and a successful heartbeat.
- Transition-only health events are retained locally in a bounded journal. Routine successful heartbeats do not create history rows; an explicit manual heartbeat still creates a controller command session.
- Medication schedules and reminders remain active on the phone while controller movement is unavailable.
- Automatic health activity never changes dose, inventory, or carousel-slot state.

This policy is covered by app and simulator tests. Physical BLE timing,
disconnect behavior, and recovery still require the XIAO and Android phone bench
check and are not yet verified.

Offline states to represent:

- Bluetooth disconnected.
- XIAO not responding.
- XIAO likely lost power.
- XIAO restarted.
- Servo power issue suspected.
- Unknown hardware error.
