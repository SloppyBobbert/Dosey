#pragma once

namespace dosey::hardware::grove_base {

inline constexpr int kMiniPirPin = 0;
inline constexpr int kLightSensorPin = 1;
inline constexpr int kActiveBuzzerPin = 2;
inline constexpr int kI2cSdaPin = 22;
inline constexpr int kI2cSclPin = 23;
inline constexpr int kUartTxPin = 16;
inline constexpr int kUartRxPin = 17;
inline constexpr int kFirstButtonFirstPin = kUartTxPin;
inline constexpr int kFirstButtonSecondPin = kUartRxPin;

// The Grove Servo uses the first signal on the D8/A8 socket.
inline constexpr int kServoPin = 19;
inline constexpr int kSecondButtonFirstPin = 20;
inline constexpr int kSecondButtonSecondPin = 18;
inline constexpr int kDiagnosticButtonPins[] = {
    kFirstButtonFirstPin,
    kFirstButtonSecondPin,
    kSecondButtonFirstPin,
    kSecondButtonSecondPin,
};
inline constexpr int kDht20Address = 0x38;

} // namespace dosey::hardware::grove_base
