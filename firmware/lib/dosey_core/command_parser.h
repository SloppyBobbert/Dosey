#pragma once

#include "protocol_config.h"

namespace dosey {

enum class CommandType {
  status,
  heartbeat,
  ledTest,
  pirStatus,
  servoTest,
  dispenseTest,
  dispenseNext,
  cancel,
};

enum class ParseError {
  none,
  empty,
  lineTooLong,
  malformed,
  unsupportedVersion,
  invalidId,
  unknownCommand,
};

struct Command {
  CommandType type = CommandType::status;
  char id[kMaxCommandIdLength + 1] = {};
};

struct ParseResult {
  bool ok = false;
  Command command;
  ParseError error = ParseError::none;
};

ParseResult parseCommand(const char *line);
const char *parseErrorCode(ParseError error);
const char *commandName(CommandType type);

} // namespace dosey
