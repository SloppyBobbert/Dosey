#include <Arduino.h>

#include "hardware_config.h"
#include "safety_limits.h"

namespace {

std::uint32_t nextReportMs = 0;

} // namespace

void setup() {
  Serial.begin(dosey::safety::kSerialBaud);
  delay(dosey::safety::kSerialStartupWaitMs);
  Serial.println("DOSEY BRINGUP 04 PIR_INPUT");

  if constexpr (!dosey::hardware::kPirConfigured) {
    Serial.println("CONFIGURATION_REQUIRED PIR_INPUT");
    return;
  }

  pinMode(dosey::hardware::kPirPin, INPUT);
}

void loop() {
  if constexpr (!dosey::hardware::kPirConfigured) {
    delay(1000);
    return;
  }

  if (static_cast<std::int32_t>(millis() - nextReportMs) >= 0) {
    Serial.printf("PIR_RAW %d\n", digitalRead(dosey::hardware::kPirPin));
    nextReportMs = millis() + dosey::safety::kInputReportIntervalMs;
  }
}
