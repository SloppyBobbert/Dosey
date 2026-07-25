#include <Arduino.h>
#include <Wire.h>

#include "hardware_config.h"
#include "safety_limits.h"

void setup() {
  Serial.begin(dosey::safety::kSerialBaud);
  delay(dosey::safety::kSerialStartupWaitMs);
  Serial.println("DOSEY BRINGUP 06 I2C_SCANNER");

  if constexpr (!dosey::hardware::kI2cConfigured) {
    Serial.println("CONFIGURATION_REQUIRED I2C_GROVE_PATH");
    return;
  }

  Wire.begin(dosey::hardware::kI2cSdaPin, dosey::hardware::kI2cSclPin);
  Serial.println("I2C_SCAN_READY");
}

void loop() {
  if constexpr (!dosey::hardware::kI2cConfigured) {
    delay(1000);
    return;
  }

  int devices = 0;
  for (std::uint8_t address = 1; address < 127; ++address) {
    Wire.beginTransmission(address);
    if (Wire.endTransmission() == 0) {
      Serial.printf("I2C_DEVICE 0x%02X\n", address);
      ++devices;
    }
  }
  Serial.printf("I2C_SCAN_DONE %d\n", devices);
  delay(2000);
}
