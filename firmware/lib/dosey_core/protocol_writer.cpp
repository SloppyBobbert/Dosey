#include "protocol_writer.h"

#include <cstdio>

#include "protocol_config.h"

namespace dosey {
namespace {

bool writeLine(char *output, std::size_t outputSize, const char *kind,
               const char *commandId, const char *code) {
  if (output == nullptr || outputSize == 0 || commandId == nullptr ||
      code == nullptr) {
    return false;
  }

  const int written = std::snprintf(output, outputSize, "%s %s %s %s",
                                    kProtocolVersion, kind, commandId, code);
  if (written < 0 || static_cast<std::size_t>(written) >= outputSize) {
    output[0] = '\0';
    return false;
  }
  return true;
}

} // namespace

bool writeEvent(char *output, std::size_t outputSize, const char *commandId,
                const char *eventCode) {
  return writeLine(output, outputSize, "EVT", commandId, eventCode);
}

bool writeNack(char *output, std::size_t outputSize, const char *commandId,
               const char *reasonCode) {
  return writeLine(output, outputSize, "NACK", commandId, reasonCode);
}

bool writeError(char *output, std::size_t outputSize, const char *commandId,
                const char *errorCode) {
  return writeLine(output, outputSize, "ERROR", commandId, errorCode);
}

} // namespace dosey
