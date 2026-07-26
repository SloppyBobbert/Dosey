#pragma once

#include <cstring>

namespace dosey {

enum class DebugOutputState { unchanged, enabled, disabled };

inline DebugOutputState debugOutputState(const char *line) {
  if (line == nullptr) {
    return DebugOutputState::unchanged;
  }

  constexpr char kEventPrefix[] = "D1 EVT ";
  constexpr char kEnabledSuffix[] = " DEBUG_ON";
  constexpr char kDisabledSuffix[] = " DEBUG_OFF";
  const std::size_t length = std::strlen(line);
  if (std::strncmp(line, kEventPrefix, sizeof(kEventPrefix) - 1) != 0) {
    return DebugOutputState::unchanged;
  }
  if (length > sizeof(kEventPrefix) + sizeof(kEnabledSuffix) - 2 &&
      std::strcmp(line + length - (sizeof(kEnabledSuffix) - 1),
                  kEnabledSuffix) == 0) {
    return DebugOutputState::enabled;
  }
  if (length > sizeof(kEventPrefix) + sizeof(kDisabledSuffix) - 2 &&
      std::strcmp(line + length - (sizeof(kDisabledSuffix) - 1),
                  kDisabledSuffix) == 0) {
    return DebugOutputState::disabled;
  }
  return DebugOutputState::unchanged;
}

} // namespace dosey
