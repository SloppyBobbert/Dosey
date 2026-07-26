#pragma once

namespace dosey::hardware::expansion_board {

inline constexpr int kMiniPirPin = 0;
inline constexpr int kOnboardButtonPin = 1;
inline constexpr int kOnboardBuzzerPin = 21;
inline constexpr int kI2cSdaPin = 22;
inline constexpr int kI2cSclPin = 23;

// The direct SG90 header uses D6, so the UART Grove socket must stay empty.
inline constexpr int kServoPin = 16;
inline constexpr int kUartTxPin = kServoPin;
inline constexpr int kUartRxPin = 17;

} // namespace dosey::hardware::expansion_board
