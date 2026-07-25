#pragma once

#include <cstddef>

namespace dosey::ble {

inline constexpr char kDeviceName[] = "Dosey-XIAO-C6";
inline constexpr char kServiceUuid[] = "8f3a1001-6f5b-4d4f-9c2a-5d6e7f801001";
inline constexpr char kCommandCharacteristicUuid[] =
    "8f3a1002-6f5b-4d4f-9c2a-5d6e7f801001";
inline constexpr char kEventCharacteristicUuid[] =
    "8f3a1003-6f5b-4d4f-9c2a-5d6e7f801001";
inline constexpr std::size_t kChunkSize = 20;

} // namespace dosey::ble
