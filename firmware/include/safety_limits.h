#pragma once

#include <cstdint>

namespace dosey::safety {

inline constexpr std::uint32_t kSerialBaud = 115200;
inline constexpr std::uint32_t kSerialStartupWaitMs = 1500;
inline constexpr std::uint32_t kInputReportIntervalMs = 250;
inline constexpr std::uint32_t kOutputTestDurationMs = 300;
inline constexpr std::uint32_t kLedTestDurationMs = 250;

inline constexpr int kServoMinimumPulseUs = 1000;
inline constexpr int kServoMaximumPulseUs = 2000;
inline constexpr int kServoHomeDegrees = 90;
inline constexpr int kServoTestDegrees = 100;
inline constexpr std::uint32_t kServoStepSettleMs = 500;
inline constexpr std::uint32_t kMovementTimeoutMs = 2500;

static_assert(kServoTestDegrees - kServoHomeDegrees <= 10,
              "Bring-up servo travel must remain conservative");
static_assert(kServoTestDegrees >= kServoHomeDegrees,
              "Bring-up servo direction must be reviewed before changing");
static_assert(kServoHomeDegrees >= 0 && kServoTestDegrees <= 180,
              "Servo angles must stay within the library range");
static_assert(kServoMinimumPulseUs > 0 &&
                  kServoMinimumPulseUs < kServoMaximumPulseUs,
              "Servo pulse limits must be ordered and positive");
static_assert(3 * kServoStepSettleMs < kMovementTimeoutMs,
              "Movement timeout must exceed the commanded sequence");

} // namespace dosey::safety
