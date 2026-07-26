# Firmware

Incremental Arduino/PlatformIO C++ bring-up firmware for the Seeed Studio XIAO ESP32-C6. The current no-solder layout uses [Grove Base SKU 103020312](https://www.seeedstudio.com/Grove-Shield-for-Seeeduino-XIAO-p-4621.html), but external paths remain disabled until their pins, active levels, power paths, and physical behavior are verified.

This is prototype firmware. Test only with candy, beads, dry beans, vitamins, or fake pills. Do not use real prescription medication during bring-up.

## Firmware role

The XIAO handles direct hardware actions and status: servo movement, PIR input, LEDs, buttons, basic sensors, heartbeat replies, and hardware error reporting. The phone owns medication names, schedules, dose decisions, refill logic, history, caregiver behavior, PIN logic, voice, and medical copy.

A servo completion event reports movement only. It never proves that a dose is visible, correct, or taken.

## Toolchain

`platformio.ini` pins Seeed's Arduino-capable PlatformIO platform to commit `9ba53b691fb007d9c1b8fd37600cc71d6702125a`:

```ini
platform = https://github.com/Seeed-Studio/platform-seeedboards.git#9ba53b691fb007d9c1b8fd37600cc71d6702125a
board = seeed-xiao-esp32-c6
framework = arduino
```

That platform currently resolves Arduino-ESP32 3.3.7 for the XIAO ESP32-C6. The servo-only environments pin `madhephaestus/ESP32Servo` 3.2.1.

Run commands from this directory with PlatformIO Core 6.1.19:

```sh
/tmp/dosey-platformio/bin/pio run -e 01_blink_serial
/tmp/dosey-platformio/bin/pio test -e native_parser
/tmp/dosey-platformio/bin/pio test -e native_state
/tmp/dosey-platformio/bin/pio test -e native_protocol
/tmp/dosey-platformio/bin/pio test -e native_protocol_debug
/tmp/dosey-platformio/bin/pio test -e native_config
/tmp/dosey-platformio/bin/pio test -e native_config_defaults
```

For a clean machine, install the same tool versions used by Firmware CI in an
isolated Python environment:

```sh
python3 -m venv /tmp/dosey-platformio
/tmp/dosey-platformio/bin/python -m pip install platformio==6.1.19 intelhex==2.3.0
```

The commands below use that pinned executable directly.

## Layout

- `include/hardware_config.h`: centralized pins and explicit external-hardware enable flags.
- `include/grove_base_pins.h`: named ESP32-C6 GPIO assignments for the selected Grove Base layout.
- `include/hardware_config.local.h.example`: safe template for ignored, bench-only configuration overrides.
- `include/protocol_config.h`: protocol version and input bounds.
- `include/debug_config.h`: compile-time availability for volatile USB diagnostics.
- `include/firmware_identity.h`: stable firmware and board-profile identity events.
- `include/ble_config.h`: fixed BLE device name, GATT UUIDs, and chunk size.
- `include/safety_limits.h`: conservative timing, pulse, and travel limits.
- `lib/dosey_core/`: host-testable framing, parser, protocol engine, line writer, and movement state.
- `bringup/`: independent bring-up programs plus the safe controller baseline entry point.
- `test/test_native/`: native parser, protocol transcript, configuration, writer, and movement-state tests.

## Bring-up environments

| Environment | Purpose | Current hardware state |
| --- | --- | --- |
| `01_blink_serial` | USB serial and onboard user LED | Ready for XIAO-only physical test |
| `02_digital_output` | One external digital output | Disabled; pin unconfirmed |
| `03_button_input` | One button input | Disabled; Dual Button integration remains pending |
| `04_pir_input` | PIR input | Disabled; Mini PIR selected for `D0/A0` but pin behavior unverified |
| `05_analog_input` | One analog input | Disabled; Light Sensor selected for `D1/A1` but 3.3 V behavior remains to be verified |
| `06_i2c_scanner` | Scan a verified Grove I2C path | Disabled; DHT20 selected but the Grove Base bus has not been scanned |
| `07_servo_sweep` | Commanded 10-degree servo test | Disabled; Grove Servo selected for `D8/A8`; repeated one-slot behavior remains unverified |
| `08_serial_protocol` | Versioned USB serial command demo | Compiles; external commands stay disabled |
| `09_ble_protocol` | Same D1 engine over BLE GATT | Compiles; radio behavior and external hardware unverified |
| `controller_baseline` | Primary flash target using the BLE D1 engine | Safe defaults compile; physical radio and hardware behavior remain unverified |
| `controller_debug` | Same safe defaults with runtime USB diagnostics available | Debug starts off after every boot; BLE toggles USB output only |

Disabled programs print `CONFIGURATION_REQUIRED` and do not configure or drive their external pins. The servo is detached at boot and cannot move unless the local configuration enables it and assigns a pin after physical verification. `DISPENSE_NEXT` remains disabled regardless of that flag.

## Local hardware configuration

Committed builds always use safe defaults with every external path disabled.
After identifying one disconnected module and its authoritative pin mapping,
create `include/hardware_config.local.h` from the adjacent example and change
only that module's enable flag and pin. Git ignores the local file.

The template already names the selected Grove Base pins but leaves every
external path disabled. The build fails at compile time if an enabled path has
no pin or if the servo shares a configured signal pin with another firmware
path. The local file does not bypass the physical test gates, power rules,
conservative servo limits, or disabled `DISPENSE_NEXT` command. Remove the local
file to return immediately to the committed safe configuration.

## Reproduce Firmware CI

Run the native suites sequentially:

```sh
/tmp/dosey-platformio/bin/pio test -e native_parser
/tmp/dosey-platformio/bin/pio test -e native_state
/tmp/dosey-platformio/bin/pio test -e native_protocol
/tmp/dosey-platformio/bin/pio test -e native_protocol_debug
/tmp/dosey-platformio/bin/pio test -e native_config
/tmp/dosey-platformio/bin/pio test -e native_config_defaults
```

Build every safe-default XIAO environment sequentially:

```sh
/tmp/dosey-platformio/bin/pio run -e 01_blink_serial
/tmp/dosey-platformio/bin/pio run -e 02_digital_output
/tmp/dosey-platformio/bin/pio run -e 03_button_input
/tmp/dosey-platformio/bin/pio run -e 04_pir_input
/tmp/dosey-platformio/bin/pio run -e 05_analog_input
/tmp/dosey-platformio/bin/pio run -e 06_i2c_scanner
/tmp/dosey-platformio/bin/pio run -e 07_servo_sweep
/tmp/dosey-platformio/bin/pio run -e 08_serial_protocol
/tmp/dosey-platformio/bin/pio run -e 09_ble_protocol
/tmp/dosey-platformio/bin/pio run -e controller_baseline
/tmp/dosey-platformio/bin/pio run -e controller_debug
/tmp/dosey-platformio/bin/pio check -e 08_serial_protocol --skip-packages
/tmp/dosey-platformio/bin/pio check -e 09_ble_protocol --skip-packages
/tmp/dosey-platformio/bin/pio check -e controller_baseline --skip-packages
/tmp/dosey-platformio/bin/pio check -e controller_debug --skip-packages
```

`.github/workflows/firmware-ci.yml` runs the same tests, builds, and protocol
static check for pull requests and pushes to `main`. These checks prove that the
code compiles and that host-side protocol transcripts match the contract. They
do not prove BLE advertising, discovery, connection stability, wiring,
electrical stability, sensor behavior, servo movement, or carousel movement.

## First physical test

Test the bare XIAO before attaching the Grove Base or any module:

1. Disconnect every external wire and module. Do not connect the battery/JST port or SWD pins.
2. Place the board on a nonconductive surface and connect it directly to the computer with a known USB data cable.
3. Run `pio device list` and record the exact port without guessing.
4. Run `/tmp/dosey-platformio/bin/pio run -e 01_blink_serial -t upload --upload-port <port>`.
5. Run `pio device monitor --port <port> --baud 115200`.
6. Confirm the serial header identifies `XIAO_ESP32_C6`, then confirm the onboard user LED changes with matching `LED ON` and `LED OFF` lines.
7. Disconnect immediately if the board heats, smells unusual, repeatedly resets, or behaves unexpectedly.

Do not record this test as passed until the LED and serial observations are made on the physical board. Attach the Grove Base and identify one module at a time only after this XIAO-only check passes.

## USB protocol bench check

After the bare-board blink/serial test passes, upload the safe-default protocol
firmware with no external hardware connected:

```sh
/tmp/dosey-platformio/bin/pio run -e 08_serial_protocol -t upload --upload-port <port>
pio device monitor --port <port> --baud 115200
```

Expected boot lines are:

```text
D1 EVT boot READY
D1 EVT boot SERVO_UNCONFIGURED
D1 EVT boot PIR_UNCONFIGURED
```

Enter `D1 CMD status-1 STATUS`. The safe-default build must return:

```text
D1 EVT status-1 COMMAND_RECEIVED
D1 EVT status-1 STATUS_OK
D1 EVT status-1 SERVO_UNCONFIGURED
D1 EVT status-1 PIR_UNCONFIGURED
D1 EVT status-1 DEBUG_UNAVAILABLE
D1 EVT status-1 DEBUG_OFF
D1 EVT status-1 MOVEMENT_IDLE
```

Enter `D1 CMD dose-1 DISPENSE_NEXT`. It must return
`D1 NACK dose-1 COMMAND_DISABLED` and must not move or attach PWM. Stop if the
board heats, smells unusual, resets repeatedly, emits unexpected output, or any
external component moves.

## Debug and readiness checks

`controller_baseline` cannot enable diagnostics. For a supervised BLE bench
session, build and upload `controller_debug`, then keep the USB serial monitor
open at 115200 baud. Debug starts off after every reboot and is never persisted.
Send `D1 CMD debug-1 DEBUG_ON` over BLE to mirror subsequent complete RX/TX
protocol lines, connection changes, invalid or oversized input, queue overflow,
and the compiled configuration snapshot to USB serial. Send
`D1 CMD debug-2 DEBUG_OFF` to stop mirroring. Diagnostic text is never added to
BLE notifications and does not enable any external path.

The read-only `DEVICE_INFO` command reports the firmware name, D1 protocol,
XIAO ESP32-C6 Grove Base profile, and baseline/debug build flavor.
`CONFIG_STATUS` reports compiled servo, PIR, I2C, and button states plus the
selected Grove Base D8 servo profile. `SAFETY_STATUS` reports the 2.5-second movement
timeout, 1000-2000 us pulse range, 90-100 degree test range, and disabled
`DISPENSE_NEXT` command. Run all three before enabling hardware and confirm all
external paths report disabled in a committed build. See
`../docs/controller_bench_runbook.md` for the exact supervised sequence.

## BLE protocol bench check

Run this only after the bare-XIAO and USB protocol checks pass. Keep the Grove
Base, servo, battery pads, and every external wire disconnected.

1. Upload `controller_baseline` with `/tmp/dosey-platformio/bin/pio run -e controller_baseline -t upload --upload-port <port>`.
2. Keep the USB serial monitor open at 115200 baud and confirm `D1 EVT boot BLE_READY`.
3. On an Android robot phone, open Controller, grant Bluetooth scan/connect access, and tap Connect.
4. Confirm the app reports both `Transport connected` and `Health: Online`. A transport connection without `HEARTBEAT_OK` must remain verifying and must not enable movement.
5. Run the explicit manual `HEARTBEAT` command and confirm its command history includes `HEARTBEAT_OK`. The app's automatic successful heartbeats update health and the last-heartbeat time without flooding command history.
6. Do not enable the servo yet. `SERVO_TEST` and `DISPENSE_TEST` must return `CONFIGURATION_REQUIRED`; `DISPENSE_NEXT` must return `COMMAND_DISABLED`.
7. Disconnect from the app and confirm the controller advertises again before reconnecting once. Then interrupt the controller connection and confirm the app fails closed and reports recovery only after a new `HEARTBEAT_OK`. That fail-closed and verified-recovery policy is app- and simulator-tested. Physical-radio recovery, the single-client limit, and automatic retry timing remain unverified until observed on the bench.

The BLE service UUID is `8f3a1001-6f5b-4d4f-9c2a-5d6e7f801001`. The write
characteristic ends in `1002`, and the notify characteristic ends in `1003`.
Both transports use the same newline-delimited D1 messages. The app and firmware
split BLE writes/notifications into conservative 20-byte chunks and reassemble
complete bounded lines.

The pinned Arduino-ESP32 3.3.7 NimBLE stack automatically creates the `0x2902`
client configuration descriptor for a notify characteristic. Its `BLE2902`
compatibility class is deprecated and warns against adding that descriptor
manually.

Stop on heat, smell, resets, repeated connection loss, malformed responses, or
any unexpected output or movement. Record observed BLE behavior separately from
compile/test evidence.

## Safety behavior

- External outputs start inactive; disabled paths never call their hardware initialization functions.
- Servo programs never attach PWM or move at boot.
- USB input is bounded to 96 characters; an oversized line is rejected and the next newline-delimited command can still be processed.
- Servo movement is nonblocking, allows only one active movement, rejects busy or duplicate active command IDs, and has a 2.5-second deadline.
- `CANCEL` detaches PWM and reports the movement as unresolved, not successful.
- Timeout detaches PWM and emits `MOVEMENT_TIMEOUT`.
- Servo attachment failure emits `SERVO_ATTACH_FAILED` before movement starts.
- `DISPENSE_TEST` is movement-only. `DISPENSE_NEXT` returns `COMMAND_DISABLED` until carousel movement meets the mechanical test gate.
- Motors must not be powered from the phone or a XIAO GPIO pin. Prior loaded movement on the Expansion Board's 3.3 V Grove socket is accepted as compatibility evidence for the Grove Servo on the Grove Base's `D8/A8` socket. Continue supervised testing and stop on weak movement, jitter, resets, disconnects, or heat.

See `../docs/protocol.md` for the implemented serial demo and `../docs/wiring.md` for confirmed versus pending wiring.
