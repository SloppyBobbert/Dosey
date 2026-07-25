#pragma once

#include <cstddef>

namespace dosey {

bool writeEvent(char *output, std::size_t outputSize, const char *commandId,
                const char *eventCode);
bool writeNack(char *output, std::size_t outputSize, const char *commandId,
               const char *reasonCode);
bool writeError(char *output, std::size_t outputSize, const char *commandId,
                const char *errorCode);

} // namespace dosey
