#pragma once

#include <cstddef>

namespace dosey {

inline constexpr char kProtocolVersion[] = "D1";
inline constexpr std::size_t kMaxCommandIdLength = 24;
inline constexpr std::size_t kMaxProtocolLineLength = 96;

} // namespace dosey
