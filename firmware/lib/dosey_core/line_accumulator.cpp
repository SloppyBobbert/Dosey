#include "line_accumulator.h"

namespace dosey {

LineResult LineAccumulator::push(char character) {
  if (character == '\n') {
    const bool wasOverflowed = overflow_;
    const bool wasInvalid = invalid_;
    if (!wasOverflowed && !wasInvalid) {
      line_[length_] = '\0';
    }
    length_ = 0;
    overflow_ = false;
    invalid_ = false;
    if (wasInvalid) {
      return LineResult::lineInvalid;
    }
    return wasOverflowed ? LineResult::lineTooLong : LineResult::lineReady;
  }

  const unsigned char byte = static_cast<unsigned char>(character);
  if (character != '\r' && (byte < 0x20 || byte > 0x7e)) {
    invalid_ = true;
  }

  if (!overflow_ && !invalid_) {
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
  invalid_ = false;
}

} // namespace dosey
