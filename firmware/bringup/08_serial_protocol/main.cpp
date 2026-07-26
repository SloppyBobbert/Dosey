#include <Arduino.h>

#include "arduino_protocol_hardware.h"
#include "hardware_config.h"
#include "line_accumulator.h"
#include "protocol_engine.h"
#include "safety_limits.h"

namespace {

class SerialProtocolOutput final : public dosey::ProtocolOutput {
public:
  bool writeLine(const char *line) override { return Serial.println(line) > 0; }
};

dosey::LineAccumulator input;
SerialProtocolOutput output;
dosey::ArduinoProtocolHardware hardware;
dosey::ProtocolEngine protocol(hardware, output);

void readSerial() {
  while (Serial.available()) {
    const dosey::LineResult result =
        input.push(static_cast<char>(Serial.read()));
    if (result == dosey::LineResult::lineReady) {
      protocol.handleLine(input.line(), millis());
    } else if (result == dosey::LineResult::lineTooLong) {
      protocol.handleLineTooLong();
    } else if (result == dosey::LineResult::lineInvalid) {
      protocol.handleLineInvalid();
    }
  }
}

} // namespace

void setup() {
  digitalWrite(dosey::hardware::kOnboardLedPin, dosey::inactiveLedLevel());
  pinMode(dosey::hardware::kOnboardLedPin, OUTPUT);
  hardware.begin();

  Serial.begin(dosey::safety::kSerialBaud);
  delay(dosey::safety::kSerialStartupWaitMs);
  Serial.println("D1 EVT boot READY");
  if constexpr (!dosey::hardware::kServoEnabled) {
    Serial.println("D1 EVT boot SERVO_UNCONFIGURED");
  }
  if constexpr (!dosey::hardware::kPirConfigured) {
    Serial.println("D1 EVT boot PIR_UNCONFIGURED");
  }
}

void loop() {
  readSerial();
  protocol.update(millis());
}
