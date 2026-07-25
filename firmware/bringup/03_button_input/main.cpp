#include <Arduino.h>

#include "hardware_config.h"
#include "safety_limits.h"

namespace {

std::uint32_t nextReportMs = 0;

} // namespace

void setup() {
  Serial.begin(dosey::safety::kSerialBaud);
  delay(dosey::safety::kSerialStartupWaitMs);
  Serial.println("DOSEY BRINGUP 03 BUTTON_INPUT");

  if constexpr (!dosey::hardware::kButtonConfigured) {
    Serial.println("CONFIGURATION_REQUIRED BUTTON_INPUT");
    return;
  }

  pinMode(dosey::hardware::kButtonPin,
          dosey::hardware::kButtonUseInternalPullup ? INPUT_PULLUP : INPUT);
}

void loop() {
  if constexpr (!dosey::hardware::kButtonConfigured) {
    delay(1000);
    return;
  }

  if (static_cast<std::int32_t>(millis() - nextReportMs) >= 0) {
    Serial.printf("BUTTON_RAW %d\n", digitalRead(dosey::hardware::kButtonPin));
    nextReportMs = millis() + dosey::safety::kInputReportIntervalMs;
  }
}
