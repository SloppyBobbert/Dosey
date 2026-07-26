#include "command_parser.h"

#include <cctype>
#include <cstdio>
#include <cstring>

namespace dosey {
namespace {

bool isValidId(const char *id) {
  const std::size_t length = std::strlen(id);
  if (length == 0 || length > kMaxCommandIdLength) {
    return false;
  }

  for (std::size_t index = 0; index < length; ++index) {
    const unsigned char character = static_cast<unsigned char>(id[index]);
    if (!std::isalnum(character) && character != '-' && character != '_') {
      return false;
    }
  }
  return true;
}

bool parseType(const char *name, CommandType &type) {
  struct Mapping {
    const char *name;
    CommandType type;
  };
  constexpr Mapping mappings[] = {
      {"STATUS", CommandType::status},
      {"HEARTBEAT", CommandType::heartbeat},
      {"DEVICE_INFO", CommandType::deviceInfo},
      {"CONFIG_STATUS", CommandType::configStatus},
      {"SAFETY_STATUS", CommandType::safetyStatus},
      {"LED_TEST", CommandType::ledTest},
      {"PIR_STATUS", CommandType::pirStatus},
      {"SERVO_TEST", CommandType::servoTest},
      {"DISPENSE_TEST", CommandType::dispenseTest},
      {"DISPENSE_NEXT", CommandType::dispenseNext},
      {"DEBUG_ON", CommandType::debugOn},
      {"DEBUG_OFF", CommandType::debugOff},
      {"CANCEL", CommandType::cancel},
  };

  for (const Mapping &mapping : mappings) {
    if (std::strcmp(name, mapping.name) == 0) {
      type = mapping.type;
      return true;
    }
  }
  return false;
}

} // namespace

ParseResult parseCommand(const char *line) {
  ParseResult result;
  if (line == nullptr || line[0] == '\0') {
    result.error = ParseError::empty;
    return result;
  }

  std::size_t length = 0;
  while (length <= kMaxProtocolLineLength && line[length] != '\0') {
    ++length;
  }
  if (length > kMaxProtocolLineLength) {
    result.error = ParseError::lineTooLong;
    return result;
  }

  char buffer[kMaxProtocolLineLength + 1];
  std::memcpy(buffer, line, length + 1);
  while (length > 0 &&
         (buffer[length - 1] == '\r' || buffer[length - 1] == '\n')) {
    buffer[--length] = '\0';
  }
  if (length == 0) {
    result.error = ParseError::empty;
    return result;
  }

  char version[3] = {};
  char marker[4] = {};
  char id[kMaxCommandIdLength + 2] = {};
  char command[22] = {};
  char trailing = '\0';
  const int fields = std::sscanf(buffer, "%2s %3s %25s %21s %c", version,
                                 marker, id, command, &trailing);
  if (fields != 4) {
    result.error = ParseError::malformed;
    return result;
  }
  if (std::strcmp(version, kProtocolVersion) != 0) {
    result.error = ParseError::unsupportedVersion;
    return result;
  }
  if (std::strcmp(marker, "CMD") != 0) {
    result.error = ParseError::malformed;
    return result;
  }
  if (!isValidId(id)) {
    result.error = ParseError::invalidId;
    return result;
  }
  if (!parseType(command, result.command.type)) {
    result.error = ParseError::unknownCommand;
    return result;
  }

  std::strcpy(result.command.id, id);
  result.ok = true;
  return result;
}

const char *parseErrorCode(ParseError error) {
  switch (error) {
  case ParseError::none:
    return "NONE";
  case ParseError::empty:
    return "EMPTY_COMMAND";
  case ParseError::lineTooLong:
    return "LINE_TOO_LONG";
  case ParseError::malformed:
    return "MALFORMED_COMMAND";
  case ParseError::unsupportedVersion:
    return "UNSUPPORTED_VERSION";
  case ParseError::invalidId:
    return "INVALID_COMMAND_ID";
  case ParseError::unknownCommand:
    return "UNKNOWN_COMMAND";
  }
  return "UNKNOWN_PARSE_ERROR";
}

const char *commandName(CommandType type) {
  switch (type) {
  case CommandType::status:
    return "STATUS";
  case CommandType::heartbeat:
    return "HEARTBEAT";
  case CommandType::deviceInfo:
    return "DEVICE_INFO";
  case CommandType::configStatus:
    return "CONFIG_STATUS";
  case CommandType::safetyStatus:
    return "SAFETY_STATUS";
  case CommandType::ledTest:
    return "LED_TEST";
  case CommandType::pirStatus:
    return "PIR_STATUS";
  case CommandType::servoTest:
    return "SERVO_TEST";
  case CommandType::dispenseTest:
    return "DISPENSE_TEST";
  case CommandType::dispenseNext:
    return "DISPENSE_NEXT";
  case CommandType::debugOn:
    return "DEBUG_ON";
  case CommandType::debugOff:
    return "DEBUG_OFF";
  case CommandType::cancel:
    return "CANCEL";
  }
  return "UNKNOWN_COMMAND";
}

} // namespace dosey
