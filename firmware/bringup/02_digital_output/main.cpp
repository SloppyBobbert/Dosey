#include <Arduino.h>

#include "hardware_config.h"
#include "safety_limits.h"

namespace {

bool outputActive = false;
std::uint32_t outputDeadlineMs = 0;

int inactiveLevel() {
  return dosey::hardware::kDigitalOutputActiveHigh ? LOW : HIGH;
}

int activeLevel() {
  return dosey::hardware::kDigitalOutputActiveHigh ? HIGH : LOW;
}

} // namespace

void setup() {
  Serial.begin(dosey::safety::kSerialBaud);
  delay(dosey::safety::kSerialStartupWaitMs);
  Serial.println("DOSEY BRINGUP 02 DIGITAL_OUTPUT");

  if constexpr (!dosey::hardware::kDigitalOutputConfigured) {
    Serial.println("CONFIGURATION_REQUIRED DIGITAL_OUTPUT");
    return;
  }

  digitalWrite(dosey::hardware::kDigitalOutputPin, inactiveLevel());
  pinMode(dosey::hardware::kDigitalOutputPin, OUTPUT);
  Serial.println("TYPE RUN TO PULSE OUTPUT");
}

void loop() {
  if constexpr (!dosey::hardware::kDigitalOutputConfigured) {
    delay(1000);
    return;
  }

  if (!outputActive && Serial.available()) {
    String input = Serial.readStringUntil('\n');
    input.trim();
    if (input == "RUN") {
      digitalWrite(dosey::hardware::kDigitalOutputPin, activeLevel());
      outputDeadlineMs = millis() + dosey::safety::kOutputTestDurationMs;
      outputActive = true;
      Serial.println("OUTPUT_STARTED");
    }
  }

  if (outputActive &&
      static_cast<std::int32_t>(millis() - outputDeadlineMs) >= 0) {
    digitalWrite(dosey::hardware::kDigitalOutputPin, inactiveLevel());
    outputActive = false;
    Serial.println("OUTPUT_DONE");
  }
}
