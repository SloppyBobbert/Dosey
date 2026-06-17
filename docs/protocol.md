# Protocol

Draft Bluetooth command and status messages between the Flutter app and XIAO controller.

The app must not log dispense success without a controller success event. It must not mark a dose taken until the user confirms the dose was taken.

## Responsibilities

The phone owns schedules, medication data, refill logic, dose history, PIN checks, caregiver logic, UI, reminders, and future voice/cloud features.

The XIAO owns direct hardware actions and reports: servo movement, PIR status, LEDs, buzzer/vibration, buttons, basic sensors, heartbeat/status, and error codes.

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
