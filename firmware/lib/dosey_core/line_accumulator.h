#pragma once

#include <cstddef>

#include "protocol_config.h"

namespace dosey {

enum class LineResult { pending, lineReady, lineTooLong, lineInvalid };

class LineAccumulator {
public:
  LineResult push(char character);
  void reset();
  const char *line() const { return line_; }

private:
  char line_[kMaxProtocolLineLength + 1] = {};
  std::size_t length_ = 0;
  bool overflow_ = false;
  bool invalid_ = false;
};

} // namespace dosey
