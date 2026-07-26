#include "protocol_engine.h"

#include <cstdio>
#include <cstring>

#include "debug_config.h"
#include "firmware_identity.h"
#include "hardware_config.h"
#include "protocol_writer.h"
#include "safety_limits.h"

namespace dosey {

static_assert(safety::kMovementTimeoutMs == 2500);
static_assert(safety::kServoMinimumPulseUs == 1000 &&
              safety::kServoMaximumPulseUs == 2000);
static_assert(safety::kServoHomeDegrees == 90 &&
              safety::kServoTestDegrees == 100);

void ProtocolEngine::handleLine(const char *line, std::uint32_t nowMs) {
  const ParseResult parsed = parseCommand(line);
  if (!parsed.ok) {
    sendNack("none", parseErrorCode(parsed.error));
    return;
  }
  handleCommand(parsed.command, nowMs);
}

void ProtocolEngine::handleLineTooLong() { sendNack("none", "LINE_TOO_LONG"); }

void ProtocolEngine::handleLineInvalid() {
  sendNack("none", "MALFORMED_COMMAND");
}

void ProtocolEngine::handleTransportDisconnect() {
  if (!controller_.isMoving()) {
    return;
  }
  controller_.cancelMovement();
  hardware_.stopMovement();
}

void ProtocolEngine::update(std::uint32_t nowMs) {
  if (hardware_.pirWakeConfigured()) {
    const bool active = hardware_.pirWakeActive();
    if (active &&
        (!pirWakeWasActive_ ||
         static_cast<std::int32_t>(nowMs - pirWakeRepeatAtMs_) >= 0)) {
      sendEvent("pir", "WAKE_FACE");
      pirWakeRepeatAtMs_ = nowMs + safety::kPirWakeRepeatIntervalMs;
    }
    pirWakeWasActive_ = active;
  }

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

  if (!controller_.isMoving()) {
    return;
  }

  const HardwareMovementUpdate movementUpdate =
      hardware_.updateMovement(nowMs);
  if (movementUpdate == HardwareMovementUpdate::writeFailed) {
    hardware_.stopMovement();
    controller_.cancelMovement();
    sendError(controller_.activeCommandId(), "SERVO_WRITE_FAILED");
    return;
  }
  if (movementUpdate == HardwareMovementUpdate::completed) {
    if (hardware_.stopMovement() == HardwareMovementStopResult::detachFailed) {
      controller_.cancelMovement();
      sendError(controller_.activeCommandId(), "SERVO_DETACH_FAILED");
      return;
    }
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
              debug::kAvailable ? "DEBUG_AVAILABLE" : "DEBUG_UNAVAILABLE");
    sendEvent(command.id, debugEnabled_ ? "DEBUG_ON" : "DEBUG_OFF");
    sendEvent(command.id,
              controller_.isMoving() ? "MOVEMENT_ACTIVE" : "MOVEMENT_IDLE");
    return;
  case CommandType::heartbeat:
    sendEvent(command.id, "COMMAND_RECEIVED");
    sendEvent(command.id, "HEARTBEAT_OK");
    return;
  case CommandType::deviceInfo:
    sendEvent(command.id, "COMMAND_RECEIVED");
    sendEvent(command.id, "DEVICE_INFO_OK");
    sendEvent(command.id, firmware::kNameEvent);
    sendEvent(command.id, "PROTOCOL_D1");
    sendEvent(command.id, firmware::kBoardProfileEvent);
    sendEvent(command.id, debug::kAvailable ? "BUILD_DEBUG" : "BUILD_BASELINE");
    return;
  case CommandType::configStatus:
    sendEvent(command.id, "COMMAND_RECEIVED");
    sendEvent(command.id, "CONFIG_STATUS_OK");
    sendEvent(command.id,
              hardware_.servoConfigured() ? "SERVO_ENABLED" : "SERVO_DISABLED");
    sendEvent(command.id,
              hardware_.pirConfigured() ? "PIR_ENABLED" : "PIR_DISABLED");
    sendEvent(command.id,
              hardware::kI2cConfigured ? "I2C_ENABLED" : "I2C_DISABLED");
    sendEvent(command.id, hardware::kButtonConfigured ? "BUTTON_ENABLED"
                                                       : "BUTTON_DISABLED");
    sendEvent(command.id,
              hardware_.groveDiagnosticsConfigured()
                  ? "GROVE_DIAGNOSTICS_ENABLED"
                  : "GROVE_DIAGNOSTICS_DISABLED");
    sendEvent(command.id, "GROVE_BASE_D8_SERVO_PROFILE");
    return;
  case CommandType::safetyStatus:
    sendEvent(command.id, "COMMAND_RECEIVED");
    sendEvent(command.id, "SAFETY_STATUS_OK");
    sendEvent(command.id, "MOVEMENT_TIMEOUT_MS_2500");
    sendEvent(command.id, "SERVO_PULSE_US_1000_2000");
    sendEvent(command.id, "SERVO_ANGLES_DEG_90_100");
    sendEvent(command.id, "DISPENSE_NEXT_DISABLED");
    return;
  case CommandType::groveDiagnostics: {
    if (!hardware_.groveDiagnosticsConfigured()) {
      sendNack(command.id, "CONFIGURATION_REQUIRED");
      return;
    }
    sendEvent(command.id, "COMMAND_RECEIVED");
    sendEvent(command.id, "GROVE_DIAGNOSTICS_OK");
    sendRawValue(command.id, "PIR_RAW", hardware_.grovePirRaw());
    sendRawValue(command.id, "LIGHT_RAW", hardware_.groveLightRaw());
    constexpr const char *kButtonLabels[] = {
        "BUTTON_1A_RAW", "BUTTON_1B_RAW", "BUTTON_2A_RAW", "BUTTON_2B_RAW"};
    for (std::uint8_t index = 0; index < 4; ++index) {
      sendRawValue(command.id, kButtonLabels[index],
                   hardware_.groveButtonRaw(index));
    }
    sendEvent(command.id, hardware_.groveDht20Present() ? "DHT20_PRESENT"
                                                        : "DHT20_NOT_FOUND");
    return;
  }
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
  case CommandType::debugOn:
    if (!debug::kAvailable) {
      sendNack(command.id, "COMMAND_DISABLED");
      return;
    }
    sendEvent(command.id, "COMMAND_RECEIVED");
    debugEnabled_ = true;
    sendEvent(command.id, "DEBUG_ON");
    return;
  case CommandType::debugOff:
    if (!debug::kAvailable) {
      sendNack(command.id, "COMMAND_DISABLED");
      return;
    }
    sendEvent(command.id, "COMMAND_RECEIVED");
    sendEvent(command.id, "DEBUG_OFF");
    debugEnabled_ = false;
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

  if (!sendEvent(command.id, "COMMAND_RECEIVED")) {
    controller_.cancelMovement();
    hardware_.stopMovement();
    return;
  }
  const HardwareMovementStartResult movementStart =
      hardware_.startMovement(nowMs);
  if (movementStart != HardwareMovementStartResult::started) {
    controller_.cancelMovement();
    hardware_.stopMovement();
    sendError(command.id,
              movementStart == HardwareMovementStartResult::attachFailed
                  ? "SERVO_ATTACH_FAILED"
                  : "SERVO_WRITE_FAILED");
    return;
  }
  sendEvent(command.id, "MOVEMENT_STARTED");
}

bool ProtocolEngine::sendEvent(const char *id, const char *code) {
  if (writeEvent(outputLine_, sizeof(outputLine_), id, code)) {
    return output_.writeLine(outputLine_);
  }
  return false;
}

bool ProtocolEngine::sendRawValue(const char *id, const char *label, int value) {
  char code[32] = {};
  const int written = std::snprintf(code, sizeof(code), "%s_%d", label, value);
  if (written < 0 || static_cast<std::size_t>(written) >= sizeof(code)) {
    return false;
  }
  return sendEvent(id, code);
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
