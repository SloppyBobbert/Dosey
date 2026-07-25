#include <Arduino.h>

#include "hardware_config.h"
#include "safety_limits.h"

namespace {

constexpr int inactiveLedLevel() {
  return dosey::hardware::kOnboardLedActiveLow ? HIGH : LOW;
}

constexpr int activeLedLevel() {
  return dosey::hardware::kOnboardLedActiveLow ? LOW : HIGH;
}

} // namespace

void setup() {
  digitalWrite(dosey::hardware::kOnboardLedPin, inactiveLedLevel());
  pinMode(dosey::hardware::kOnboardLedPin, OUTPUT);

  Serial.begin(dosey::safety::kSerialBaud);
  delay(dosey::safety::kSerialStartupWaitMs);
  Serial.println("DOSEY BRINGUP 01 XIAO_ESP32_C6");
  Serial.println("ONBOARD_LED GPIO15 ACTIVE_LOW");
}

void loop() {
  digitalWrite(dosey::hardware::kOnboardLedPin, activeLedLevel());
  Serial.println("LED ON");
  delay(500);
  digitalWrite(dosey::hardware::kOnboardLedPin, inactiveLedLevel());
  Serial.println("LED OFF");
  delay(500);
}
