#include "line_accumulator.h"

namespace dosey {

LineResult LineAccumulator::push(char character) {
  if (character == '\n') {
    const bool wasOverflowed = overflow_;
    if (!wasOverflowed) {
      line_[length_] = '\0';
    }
    length_ = 0;
    overflow_ = false;
    return wasOverflowed ? LineResult::lineTooLong : LineResult::lineReady;
  }

  if (!overflow_) {
    if (length_ < kMaxProtocolLineLength) {
      line_[length_++] = character;
    } else {
      overflow_ = true;
    }
  }
  return LineResult::pending;
}

void LineAccumulator::reset() {
  line_[0] = '\0';
  length_ = 0;
  overflow_ = false;
}

} // namespace dosey
