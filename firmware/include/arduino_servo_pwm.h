#pragma once

#include <Arduino.h>
#include <cstdint>

namespace dosey::hardware {

class ArduinoServoPwm {
public:
  bool attach(int pin, int frequencyHz, int resolutionBits) {
    return ledcAttach(pin, frequencyHz, resolutionBits);
  }

  bool write(int pin, std::uint32_t duty) { return ledcWrite(pin, duty); }

  bool detach(int pin) { return ledcDetach(pin); }
};

} // namespace dosey::hardware
