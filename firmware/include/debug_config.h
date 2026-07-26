#pragma once

#ifndef DOSEY_DEBUG_AVAILABLE
#define DOSEY_DEBUG_AVAILABLE 0
#endif

namespace dosey::debug {

inline constexpr bool kAvailable = DOSEY_DEBUG_AVAILABLE != 0;

} // namespace dosey::debug

#undef DOSEY_DEBUG_AVAILABLE
