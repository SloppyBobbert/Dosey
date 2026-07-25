#pragma once

#include <cstdint>

#include "protocol_config.h"

namespace dosey {

enum class AcceptResult { accepted, busy, duplicateId };

enum class MovementResult { none, completed, cancelled, timedOut, notMoving };

enum class MovementOutcome {
  none,
  completed,
  cancelledUnresolved,
  timedOutUnresolved,
};

class ControllerState {
public:
  AcceptResult acceptMovement(const char *commandId, std::uint32_t nowMs,
                              std::uint32_t timeoutMs);
  MovementResult completeMovement();
  MovementResult cancelMovement();
  MovementResult update(std::uint32_t nowMs);

  bool isMoving() const { return moving_; }
  const char *activeCommandId() const { return activeCommandId_; }
  MovementOutcome lastOutcome() const { return lastOutcome_; }

private:
  void finish(MovementOutcome outcome);

  bool moving_ = false;
  std::uint32_t deadlineMs_ = 0;
  char activeCommandId_[kMaxCommandIdLength + 1] = {};
  MovementOutcome lastOutcome_ = MovementOutcome::none;
};

} // namespace dosey
