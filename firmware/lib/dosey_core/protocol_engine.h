#pragma once

#include <cstdint>

#include "command_parser.h"
#include "controller_state.h"
#include "protocol_config.h"

namespace dosey {

enum class HardwareMovementUpdate { none, completed };

class ProtocolOutput {
public:
  virtual ~ProtocolOutput() = default;
  virtual void writeLine(const char *line) = 0;
};

class ProtocolHardware {
public:
  virtual ~ProtocolHardware() = default;
  virtual bool servoConfigured() const = 0;
  virtual bool pirConfigured() const = 0;
  virtual bool pirMotion() const = 0;
  virtual void setLedActive(bool active) = 0;
  virtual bool startMovement(std::uint32_t nowMs) = 0;
  virtual void stopMovement() = 0;
  virtual HardwareMovementUpdate updateMovement(std::uint32_t nowMs) = 0;
};

class ProtocolEngine {
public:
  ProtocolEngine(ProtocolHardware &hardware, ProtocolOutput &output)
      : hardware_(hardware), output_(output) {}

  void handleLine(const char *line, std::uint32_t nowMs);
  void handleLineTooLong();
  void handleTransportDisconnect();
  void update(std::uint32_t nowMs);

private:
  void handleCommand(const Command &command, std::uint32_t nowMs);
  void startMovement(const Command &command, std::uint32_t nowMs);
  void sendEvent(const char *id, const char *code);
  void sendNack(const char *id, const char *code);
  void sendError(const char *id, const char *code);

  ProtocolHardware &hardware_;
  ProtocolOutput &output_;
  ControllerState controller_;
  bool ledTestActive_ = false;
  std::uint32_t ledDeadlineMs_ = 0;
  char ledCommandId_[kMaxCommandIdLength + 1] = {};
  char outputLine_[kMaxProtocolLineLength + 1] = {};
};

} // namespace dosey
