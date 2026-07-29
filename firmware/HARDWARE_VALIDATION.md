# Hardware validation

## 2026-07-28

This is partial evidence for open issue #61 and does not close it. Remaining validation includes servo and repeated one-slot movement, Dual Button/K2 behavior, isolated-module testing, electrical measurements, and physical movement cancellation/timeout. Battery operation was outside the current plan, was not tested, and is not a completion gate.

### Provenance

- Physical observations were captured from the old `docs/hardware-next-steps` worktree at checked-out base `6781b79654f9783b0b18fb68d76bde75dcf32ae9` while the six original candidate files were uncommitted.
- Before transfer to PR base `92713435e34f2c4d3c2cd8062f86ed3b014df8d2`, `firmware/platformio.ini`, `firmware/include`, and `firmware/lib` were proven unchanged by an empty diff and matching Git object IDs.
- The original six target files matched byte-for-byte after transfer, and automated tests/builds were rerun on the new base. Physical actions were not repeated on the PR branch.
- The active-high configured-output guard was added during review and has automated compile evidence only, not a repeated physical run.

No firmware or toolchain package downloads occurred. During final native tests, PlatformIO unpacked Unity 2.6.1 into 4,080 KiB of ignored `.pio/libdeps` test directories; no download line was observed, and the user approved keeping those generated files.

### Assembled non-servo rig

- Unpowered rig: PIR `A0/D0`, Light Sensor `A1/D1`, Active Buzzer `A2/D2`, DHT20 `A5/D5` I2C, and Dual Button `A7/D7` UART; servo absent.
- These labels are observations, not continuity proof. No multimeter was available, so rail voltage and continuity remain unverified.
- With USB connected, the XIAO slowly blinked yellow and the Grove Base green indicator blinked faster in either switch position. No heat, unusual smell, buzzer sound, resets, or disconnects were observed.
- Official documentation establishes a charge-status indicator only; the exact green blink semantics and switch direction remain unverified.
- The device enumerated as `/dev/cu.usbmodem101`, VID:PID `303A:1001`, `USB JTAG/serial debug unit`.

### Bare XIAO USB bring-up

- `01_blink_serial` physically blinked and reported `DOSEY BRINGUP 01 XIAO_ESP32_C6`, `ONBOARD_LED GPIO15 ACTIVE_LOW`, and repeated `ON`/`OFF`.
- Physical USB `08_serial_protocol` safe defaults reported boot `READY`, `SERVO_UNCONFIGURED`, and `PIR_UNCONFIGURED`; `STATUS` OK with external paths unconfigured/idle; `DEVICE_INFO` firmware/protocol/board/build; `CONFIG_STATUS` all `SERVO`/`PIR`/`I2C`/`BUTTON`/`GROVE_DIAGNOSTICS` disabled plus the D8 profile; and `SAFETY_STATUS` movement timeout 2500 ms, servo pulse 1000–2000 us, angles 90–100 degrees, and `DISPENSE_NEXT` disabled.
- `HEARTBEAT` returned OK. `SERVO_TEST` and `DISPENSE_TEST` returned `CONFIGURATION_REQUIRED`; `DISPENSE_NEXT` returned `COMMAND_DISABLED`; `CANCEL` returned `NOT_MOVING`; a malformed command returned `MALFORMED_COMMAND`; an unknown command returned `UNKNOWN_COMMAND`; a 97-character line returned `LINE_TOO_LONG`; an immediate recovery heartbeat returned OK.
- No external component activated. Movement cancellation and timeout were not physically exercised because the servo was absent.

Exact retained USB observations:

```text
D1 EVT boot READY
D1 EVT boot SERVO_UNCONFIGURED
D1 EVT boot PIR_UNCONFIGURED
D1 CMD status-1 STATUS
D1 EVT status-1 COMMAND_RECEIVED
D1 EVT status-1 STATUS_OK
D1 EVT status-1 SERVO_UNCONFIGURED
D1 EVT status-1 PIR_UNCONFIGURED
D1 EVT status-1 DEBUG_UNAVAILABLE
D1 EVT status-1 DEBUG_OFF
D1 EVT status-1 MOVEMENT_IDLE
D1 CMD info-1 DEVICE_INFO
D1 EVT info-1 COMMAND_RECEIVED
D1 EVT info-1 DEVICE_INFO_OK
D1 EVT info-1 FIRMWARE_DOSEY_CONTROLLER
D1 EVT info-1 PROTOCOL_D1
D1 EVT info-1 BOARD_XIAO_ESP32_C6_GROVE_BASE
D1 EVT info-1 BUILD_BASELINE
D1 CMD config-1 CONFIG_STATUS
D1 EVT config-1 COMMAND_RECEIVED
D1 EVT config-1 CONFIG_STATUS_OK
D1 EVT config-1 SERVO_DISABLED
D1 EVT config-1 PIR_DISABLED
D1 EVT config-1 I2C_DISABLED
D1 EVT config-1 BUTTON_DISABLED
D1 EVT config-1 GROVE_DIAGNOSTICS_DISABLED
D1 EVT config-1 GROVE_BASE_D8_SERVO_PROFILE
D1 CMD safety-1 SAFETY_STATUS
D1 EVT safety-1 COMMAND_RECEIVED
D1 EVT safety-1 SAFETY_STATUS_OK
D1 EVT safety-1 MOVEMENT_TIMEOUT_MS_2500
D1 EVT safety-1 SERVO_PULSE_US_1000_2000
D1 EVT safety-1 SERVO_ANGLES_DEG_90_100
D1 EVT safety-1 DISPENSE_NEXT_DISABLED
D1 CMD heartbeat-1 HEARTBEAT
D1 EVT heartbeat-1 COMMAND_RECEIVED
D1 EVT heartbeat-1 HEARTBEAT_OK
D1 STATUS
D1 NACK none MALFORMED_COMMAND
D1 NACK none UNKNOWN_COMMAND
D1 NACK none LINE_TOO_LONG
D1 CMD recover-1 HEARTBEAT
D1 EVT recover-1 COMMAND_RECEIVED
D1 EVT recover-1 HEARTBEAT_OK
```

The unknown-command and oversized-line inputs were not retained verbatim; their exact observed NACK lines were retained. The existing `SERVO_TEST`, `DISPENSE_TEST`, `DISPENSE_NEXT`, and `CANCEL` narrative remains without request IDs because those IDs were not retained in the evidence.

### Grove Light Sensor

- XIAO ESP32-C6 was seated in the Grove Base; the assembled non-servo rig ran over USB.
- The Light Sensor was connected at Grove Base `D1/A1`, corresponding to configured `GPIO1`.
- `05_analog_input` was built and uploaded with the already-installed `/tmp/dosey-platformio/bin/pio` and ignored local configuration enabling only analog input. I2C, output, button, PIR, servo, and diagnostics remained disabled.
- Raw ADC observations: first ambient range 1240–1272; covered range 39–207; later uncovered range 771–804.
- The user observed no heat, unusual smell, resets or disconnects, buzzer sound, or unexpected module activity.

The raw ADC changed substantially under cover and rebounded after uncovering.

This does not establish calibrated illuminance, rail voltage, continuity, identical ambient lighting, or isolated-module behavior: no multimeter was available and other non-servo modules remained connected.

Product decision: the Light Sensor is removed from planned Dosey hardware because there is no current product use. Generic analog bring-up support is retained for possible future bench use.

### I2C, button, PIR, and buzzer local builds

- The I2C-only local build repeatedly reported exactly `I2C_DEVICE 0x38` and `I2C_SCAN_DONE 1`; no other activity was observed.
- The button-only local build held stable at `BUTTON_RAW 1`. Pressing K1 produced no observed transition on the selected first-button pin; K2 was untested, and further button testing was skipped. Neither button is established as working.
- The PIR-only local build reported still `0`, hand motion 10–20 cm from the dome `1`, then still `0` again.
- The buzzer-only local build initially exposed an Arduino GPIO2 init-order error from `digitalWrite` before `pinMode`. After the tracked one-line order fix, boot was clean and silent; three separate bounded 300 ms `RUN` pulses produced three `STARTED`/`DONE` pairs, and the user heard three brief beeps.
- Other non-servo modules remained attached during these local-only path tests. External paths were enabled one at a time in ignored local configuration, so isolated one-module behavior is not established.

### Bare XIAO BLE controller baseline

- An initial GPIO15 init-order error was fixed with the same tracked one-line order change. A clean reset reported `D1 EVT boot BLE_READY`.
- Android Robot CI artifact from Mobile CI run `30416538570` / PR #54 merged commit `594981661669c7e718e8fd27294d44ad5a486b78` connected and showed the controller online.
- Observed BLE results: `HEARTBEAT` displayed `COMMAND_SENT`, `HEARTBEAT_OK`, `HEARTBEAT_OK`; `DEVICE_INFO` displayed firmware/protocol/board/build; `CONFIG_STATUS` displayed all paths disabled and the D8 profile; and `SAFETY_STATUS` displayed 2500 ms, 1000–2000 us, 90–100 degrees, and `DISPENSE_NEXT` disabled.
- `SERVO_TEST` and `DISPENSE_TEST` failed closed with `CONFIGURATION_REQUIRED`. `LED_TEST` physically blinked the yellow LED once and displayed `ACK`/`LED_TEST_STARTED`/`LED_TEST_DONE`. Disconnect changed the UI to disconnected.
- The app exposed no `CANCEL` button, so BLE cancellation was not exercised.

### Source-worktree regression verification

- GPIO initialization now calls `pinMode(..., OUTPUT)` before the first inactive `digitalWrite(...)` in `01_blink_serial`, `02_digital_output`, `08_serial_protocol`, and `controller_baseline`.
- All six native environments passed: 119 test cases total. Safe-default builds passed for `01_blink_serial`, `02_digital_output`, `08_serial_protocol`, and `controller_baseline`.
- The corrected `01_blink_serial` was uploaded to the bare XIAO in the old worktree. Fresh serial output contained the identity header and repeated `LED ON`/`LED OFF` without a GPIO initialization diagnostic; the user observed a yellow blink once per second.
- The corrected `08_serial_protocol` was then uploaded to the bare XIAO in the old worktree. Fresh startup contained only the expected safe-default boot events, and a final physical `CONFIG_STATUS` reported all external paths disabled. The yellow LED remained inactive, with no heat, unusual smell, or USB instability observed.

### Scope and safety

- No lithium battery was planned or present; battery-only operation was not tested.
- The servo remains absent and deferred. No GPIO-powered motor/servo, fake pill dispensing, heat, unusual smell, unstable power, or uncontrolled movement was observed.
- Local configuration was removed, and the final physical `CONFIG_STATUS` confirmed all external paths disabled.
