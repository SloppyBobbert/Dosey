# Protocol

Transport-independent command and status contract between the Flutter app and
XIAO controller. USB serial and BLE GATT implement the current bench
transports. Both preserve the same command IDs, response lines, and lifecycle
semantics.

The app must not log dispense success without a controller success event. It must not mark a dose taken until the user confirms the dose was taken.

The Flutter app maps both simulator and BLE commands onto its local
command-session/event lifecycle instead of letting transport code bypass it.

## Responsibilities

The phone owns schedules, medication data, refill logic, dose history, PIN checks, caregiver logic, UI, reminders, and future voice/cloud features.

The XIAO owns direct hardware actions and reports: servo movement, PIR status, LEDs, buzzer/vibration, buttons, basic sensors, heartbeat/status, and error codes.

## Implemented USB and BLE bring-up protocol

`firmware/bringup/08_serial_protocol` implements a line-oriented USB serial demo
at 115200 baud. `firmware/bringup/09_ble_protocol` runs the same protocol engine
over a single-client BLE GATT service. Both are bring-up groundwork.

The BLE peripheral advertises as `Dosey-XIAO-C6` with service UUID
`8f3a1001-6f5b-4d4f-9c2a-5d6e7f801001`, RX/write characteristic
`8f3a1002-6f5b-4d4f-9c2a-5d6e7f801001`, and TX/notify characteristic
`8f3a1003-6f5b-4d4f-9c2a-5d6e7f801001`. Each side uses 20-byte chunks and
reassembles newline-delimited bounded messages. A disconnect stops active
movement without reporting completion, clears partial transport input, and
restarts advertising. These paths compile and are host-tested where transport
independent; physical BLE behavior remains unverified.

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

Implemented commands while external hardware remains unconfigured:

| Command | Current result |
| --- | --- |
| `STATUS` | `COMMAND_RECEIVED`, `STATUS_OK`, servo configuration, PIR configuration, then movement state |
| `HEARTBEAT` | `COMMAND_RECEIVED`, then `HEARTBEAT_OK` |
| `LED_TEST` | `COMMAND_RECEIVED`, `LED_TEST_STARTED`, then `LED_TEST_DONE` |
| `PIR_STATUS` | `CONFIGURATION_REQUIRED` NACK |
| `SERVO_TEST` | `CONFIGURATION_REQUIRED` NACK |
| `DISPENSE_TEST` | `CONFIGURATION_REQUIRED` NACK |
| `DISPENSE_NEXT` | `COMMAND_DISABLED` NACK |
| `CANCEL` | `NOT_MOVING` NACK unless a movement is active |

The committed safe-default `STATUS` transcript is:

```text
D1 EVT <command-id> COMMAND_RECEIVED
D1 EVT <command-id> STATUS_OK
D1 EVT <command-id> SERVO_UNCONFIGURED
D1 EVT <command-id> PIR_UNCONFIGURED
D1 EVT <command-id> MOVEMENT_IDLE
```

When paths are physically verified and locally enabled, configuration events
change to `SERVO_CONFIGURED` and `PIR_CONFIGURED`. Movement state is
`MOVEMENT_ACTIVE` only while one movement command owns the controller path;
otherwise it is `MOVEMENT_IDLE`.

After a servo and its power path are physically verified and explicitly enabled, `SERVO_TEST` and `DISPENSE_TEST` accept one movement at a time. Their lifecycle is `COMMAND_RECEIVED`, `MOVEMENT_STARTED`, then `SERVO_DONE` or an error. An overlapping command returns `BUSY`; reuse of the active ID returns `DUPLICATE_ACTIVE_ID`. `CANCEL` detaches PWM and emits `MOVEMENT_CANCELLED_UNRESOLVED` for the interrupted command. A deadline failure detaches PWM and emits `MOVEMENT_TIMEOUT`.

`SERVO_ATTACH_FAILED` is emitted after command receipt but before
`MOVEMENT_STARTED` if the PWM path cannot attach. The firmware detaches the
servo path before reporting attach failure, cancellation, timeout, or normal
completion.

`SERVO_DONE` means only that the commanded PWM sequence completed. It is not evidence of carousel advance, dose visibility, dose correctness, or dose intake.

## Candidate commands

| Phone to XIAO | Purpose |
| --- | --- |
| `STATUS` | Request current controller state |
| `STATUS_CHECK` | Lightweight liveness/status check |
| `HEARTBEAT` | Confirm the controller is still alive |
| `DISPENSE_NEXT` | Advance the carousel one slot for a scheduled dose |
| `DISPENSE_TEST` | Test dispense movement without logging a real dose |
| `MOVE_SERVO` | Low-level movement test during bring-up |
| `SERVO_TEST` | Servo sweep or pusher test |
| `LED_ON` / `LED_OFF` | Basic LED control |
| `LED_TEST` | Feedback light test |
| `PIR_STATUS` | Request current PIR state |
| `WAKE_FACE` | Notify the phone to wake or brighten the face UI |
| `ERROR_CLEAR` | Clear a recoverable controller error after user action |

| XIAO to phone | Purpose |
| --- | --- |
| `COMMAND_RECEIVED` | Command parsed and accepted for execution |
| `NACK` | Command rejected or malformed |
| `STATUS_OK` | Controller is responsive and not reporting a blocking error |
| `HEARTBEAT_OK` | Heartbeat response |
| `SERVO_READY` | Servo path is ready for command |
| `PIR_READY` | PIR path is ready |
| `SERVO_DONE` | Servo movement completed |
| `PIR_MOTION` | PIR detected motion |
| `PIR_CLEAR` | PIR no longer detects motion |
| `ERROR_CODE` | Controller reports a fault |

## Dispense command flow

1. Phone shows a scheduled reminder.
2. User taps the screen to receive medication.
3. Phone records the dispense request time.
4. Phone sends `DISPENSE_NEXT`.
5. XIAO replies `COMMAND_RECEIVED`.
6. XIAO moves the servo to advance one slot.
7. XIAO replies `SERVO_DONE` or `ERROR_CODE`.
8. Phone shows the expected medication infographic or notes and asks: “Is this your medication you see?”
9. User confirms whether the dose is visible and correct.
10. User confirms taken, skips, reports an error, or leaves it unresolved.
11. Phone logs the final state.

The Flutter app maps BLE command IDs and D1 events into the same app-owned
lifecycle used by the simulator. A disconnect before `COMMAND_RECEIVED` is a
definite offline failure. A disconnect after receipt is interrupted and
physically ambiguous. `MOVEMENT_STARTED` remains separate from `SERVO_DONE`.
Manual `SERVO_TEST` and `DISPENSE_TEST` commands create command-session history
only; they must not write a real dose-log movement event. `DISPENSE_NEXT` stays
blocked by firmware until the mechanical Stage 2 criteria pass.

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

## Heartbeat and offline detection

The robot phone should not connect to the XIAO only when dispensing. It should regularly check that the controller is alive.

Suggested behavior:

- Send `HEARTBEAT` or `STATUS_CHECK` every 5 to 10 seconds while Robot Mode is active.
- Mark the controller unstable after 2 missed responses.
- Mark the controller offline after 3 to 5 missed responses.
- Log when the XIAO goes offline and when it reconnects.
- Disable dispensing while the controller is offline.
- Keep medication schedules and reminders active on the phone.
- If caregiver alerts are enabled, notify the caregiver when a due dose is affected by controller offline status.

Offline states to represent:

- Bluetooth disconnected.
- XIAO not responding.
- XIAO likely lost power.
- XIAO restarted.
- Servo power issue suspected.
- Unknown hardware error.
