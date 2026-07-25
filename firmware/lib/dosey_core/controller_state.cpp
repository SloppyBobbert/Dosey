#include "controller_state.h"

#include <cstring>

namespace dosey {

AcceptResult ControllerState::acceptMovement(const char *commandId,
                                             std::uint32_t nowMs,
                                             std::uint32_t timeoutMs) {
  if (moving_) {
    if (std::strncmp(activeCommandId_, commandId, kMaxCommandIdLength + 1) ==
        0) {
      return AcceptResult::duplicateId;
    }
    return AcceptResult::busy;
  }

  std::strncpy(activeCommandId_, commandId, kMaxCommandIdLength);
  activeCommandId_[kMaxCommandIdLength] = '\0';
  deadlineMs_ = nowMs + timeoutMs;
  moving_ = true;
  lastOutcome_ = MovementOutcome::none;
  return AcceptResult::accepted;
}

MovementResult ControllerState::completeMovement() {
  if (!moving_) {
    return MovementResult::notMoving;
  }
  finish(MovementOutcome::completed);
  return MovementResult::completed;
}

MovementResult ControllerState::cancelMovement() {
  if (!moving_) {
    return MovementResult::notMoving;
  }
  finish(MovementOutcome::cancelledUnresolved);
  return MovementResult::cancelled;
}

MovementResult ControllerState::update(std::uint32_t nowMs) {
  if (!moving_ || static_cast<std::int32_t>(nowMs - deadlineMs_) < 0) {
    return MovementResult::none;
  }
  finish(MovementOutcome::timedOutUnresolved);
  return MovementResult::timedOut;
}

void ControllerState::finish(MovementOutcome outcome) {
  moving_ = false;
  lastOutcome_ = outcome;
}

} // namespace dosey
