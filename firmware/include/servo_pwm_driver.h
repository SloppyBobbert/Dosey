#pragma once

#include <cstdint>

namespace dosey::hardware {

inline constexpr int kServoPwmFrequencyHz = 50;
inline constexpr int kServoPwmResolutionBits = 14;
inline constexpr std::uint32_t kServoPwmPeriodUs = 20000;
inline constexpr std::uint32_t kServoPwmMaximumDuty =
    (1U << kServoPwmResolutionBits) - 1U;

constexpr std::uint32_t servoPulseToDuty(int pulseUs) {
  return (static_cast<std::uint32_t>(pulseUs) * kServoPwmMaximumDuty +
          kServoPwmPeriodUs / 2U) /
         kServoPwmPeriodUs;
}

constexpr int servoDegreesToPulse(int degrees, int minimumPulseUs,
                                  int maximumPulseUs) {
  return minimumPulseUs +
         (degrees * (maximumPulseUs - minimumPulseUs) + 90) / 180;
}

template <typename Pwm> class ServoPwmDriver {
public:
  explicit ServoPwmDriver(Pwm &pwm) : pwm_(pwm) {}

  bool attach(int pin) {
    if (attached_) {
      return false;
    }
    if (!pwm_.attach(pin, kServoPwmFrequencyHz, kServoPwmResolutionBits)) {
      return false;
    }
    pin_ = pin;
    attached_ = true;
    return true;
  }

  bool writeMicroseconds(int pulseUs) {
    return attached_ && pwm_.write(pin_, servoPulseToDuty(pulseUs));
  }

  bool writeDegrees(int degrees, int minimumPulseUs, int maximumPulseUs) {
    return writeMicroseconds(
        servoDegreesToPulse(degrees, minimumPulseUs, maximumPulseUs));
  }

  bool detach() {
    if (!attached_) {
      return true;
    }
    if (!pwm_.detach(pin_)) {
      return false;
    }
    attached_ = false;
    pin_ = -1;
    return true;
  }

private:
  Pwm &pwm_;
  int pin_ = -1;
  bool attached_ = false;
};

} // namespace dosey::hardware
