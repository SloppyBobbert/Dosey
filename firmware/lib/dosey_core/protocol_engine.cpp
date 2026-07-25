#include "protocol_engine.h"

#include <cstring>

#include "protocol_writer.h"
#include "safety_limits.h"

namespace dosey {

void ProtocolEngine::handleLine(const char *line, std::uint32_t nowMs) {
  const ParseResult parsed = parseCommand(line);
  if (!parsed.ok) {
    sendNack("none", parseErrorCode(parsed.error));
    return;
  }
  handleCommand(parsed.command, nowMs);
}

void ProtocolEngine::handleLineTooLong() { sendNack("none", "LINE_TOO_LONG"); }

void ProtocolEngine::handleTransportDisconnect() {
  if (!controller_.isMoving()) {
    return;
  }
  controller_.cancelMovement();
  hardware_.stopMovement();
}

void ProtocolEngine::update(std::uint32_t nowMs) {
  if (ledTestActive_ &&
      static_cast<std::int32_t>(nowMs - ledDeadlineMs_) >= 0) {
    hardware_.setLedActive(false);
    ledTestActive_ = false;
    sendEvent(ledCommandId_, "LED_TEST_DONE");
  }

  if (controller_.update(nowMs) == MovementResult::timedOut) {
    hardware_.stopMovement();
    sendError(controller_.activeCommandId(), "MOVEMENT_TIMEOUT");
    return;
  }

  if (controller_.isMoving() &&
      hardware_.updateMovement(nowMs) == HardwareMovementUpdate::completed) {
    hardware_.stopMovement();
    controller_.completeMovement();
    sendEvent(controller_.activeCommandId(), "SERVO_DONE");
  }
}

void ProtocolEngine::handleCommand(const Command &command,
                                   std::uint32_t nowMs) {
  switch (command.type) {
  case CommandType::status:
    sendEvent(command.id, "COMMAND_RECEIVED");
    sendEvent(command.id, "STATUS_OK");
    sendEvent(command.id, hardware_.servoConfigured() ? "SERVO_CONFIGURED"
                                                      : "SERVO_UNCONFIGURED");
    sendEvent(command.id, hardware_.pirConfigured() ? "PIR_CONFIGURED"
                                                    : "PIR_UNCONFIGURED");
    sendEvent(command.id,
              controller_.isMoving() ? "MOVEMENT_ACTIVE" : "MOVEMENT_IDLE");
    return;
  case CommandType::heartbeat:
    sendEvent(command.id, "COMMAND_RECEIVED");
    sendEvent(command.id, "HEARTBEAT_OK");
    return;
  case CommandType::ledTest:
    if (ledTestActive_) {
      sendNack(command.id, "BUSY");
      return;
    }
    sendEvent(command.id, "COMMAND_RECEIVED");
    std::strcpy(ledCommandId_, command.id);
    hardware_.setLedActive(true);
    ledDeadlineMs_ = nowMs + safety::kLedTestDurationMs;
    ledTestActive_ = true;
    sendEvent(command.id, "LED_TEST_STARTED");
    return;
  case CommandType::pirStatus:
    if (!hardware_.pirConfigured()) {
      sendNack(command.id, "CONFIGURATION_REQUIRED");
      return;
    }
    sendEvent(command.id, "COMMAND_RECEIVED");
    sendEvent(command.id, hardware_.pirMotion() ? "PIR_MOTION" : "PIR_CLEAR");
    return;
  case CommandType::servoTest:
  case CommandType::dispenseTest:
    startMovement(command, nowMs);
    return;
  case CommandType::dispenseNext:
    sendNack(command.id, "COMMAND_DISABLED");
    return;
  case CommandType::cancel:
    if (!controller_.isMoving()) {
      sendNack(command.id, "NOT_MOVING");
      return;
    }
    sendEvent(command.id, "COMMAND_RECEIVED");
    controller_.cancelMovement();
    hardware_.stopMovement();
    sendEvent(controller_.activeCommandId(), "MOVEMENT_CANCELLED_UNRESOLVED");
    return;
  }
}

void ProtocolEngine::startMovement(const Command &command,
                                   std::uint32_t nowMs) {
  if (!hardware_.servoConfigured()) {
    sendNack(command.id, "CONFIGURATION_REQUIRED");
    return;
  }

  const AcceptResult accepted =
      controller_.acceptMovement(command.id, nowMs, safety::kMovementTimeoutMs);
  if (accepted == AcceptResult::duplicateId) {
    sendNack(command.id, "DUPLICATE_ACTIVE_ID");
    return;
  }
  if (accepted == AcceptResult::busy) {
    sendNack(command.id, "BUSY");
    return;
  }

  sendEvent(command.id, "COMMAND_RECEIVED");
  if (!hardware_.startMovement(nowMs)) {
    controller_.cancelMovement();
    hardware_.stopMovement();
    sendError(command.id, "SERVO_ATTACH_FAILED");
    return;
  }
  sendEvent(command.id, "MOVEMENT_STARTED");
}

void ProtocolEngine::sendEvent(const char *id, const char *code) {
  if (writeEvent(outputLine_, sizeof(outputLine_), id, code)) {
    output_.writeLine(outputLine_);
  }
}

void ProtocolEngine::sendNack(const char *id, const char *code) {
  if (writeNack(outputLine_, sizeof(outputLine_), id, code)) {
    output_.writeLine(outputLine_);
  }
}

void ProtocolEngine::sendError(const char *id, const char *code) {
  if (writeError(outputLine_, sizeof(outputLine_), id, code)) {
    output_.writeLine(outputLine_);
  }
}

} // namespace dosey
