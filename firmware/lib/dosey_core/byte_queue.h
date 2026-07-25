#pragma once

#include <atomic>
#include <cstddef>
#include <cstdint>

namespace dosey {

inline constexpr std::size_t kBleByteQueueCapacity = 256;

class ByteQueue {
public:
  bool push(const std::uint8_t *data, std::size_t length);
  bool pop(char &value);
  std::size_t size() const;
  void clear();

private:
  std::uint8_t data_[kBleByteQueueCapacity] = {};
  std::atomic<std::uint32_t> head_{0};
  std::atomic<std::uint32_t> tail_{0};
};

} // namespace dosey
