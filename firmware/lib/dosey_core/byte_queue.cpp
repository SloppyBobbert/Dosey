#include "byte_queue.h"

namespace dosey {

bool ByteQueue::push(const std::uint8_t *data, std::size_t length) {
  if (data == nullptr || length == 0) {
    return length == 0;
  }

  const std::uint32_t head = head_.load(std::memory_order_relaxed);
  const std::uint32_t tail = tail_.load(std::memory_order_acquire);
  if (length > kBleByteQueueCapacity - (head - tail)) {
    return false;
  }

  for (std::size_t index = 0; index < length; ++index) {
    data_[(head + index) % kBleByteQueueCapacity] = data[index];
  }
  head_.store(head + static_cast<std::uint32_t>(length),
              std::memory_order_release);
  return true;
}

bool ByteQueue::pop(char &value) {
  const std::uint32_t tail = tail_.load(std::memory_order_relaxed);
  const std::uint32_t head = head_.load(std::memory_order_acquire);
  if (tail == head) {
    return false;
  }

  value = static_cast<char>(data_[tail % kBleByteQueueCapacity]);
  tail_.store(tail + 1, std::memory_order_release);
  return true;
}

std::size_t ByteQueue::size() const {
  const std::uint32_t head = head_.load(std::memory_order_acquire);
  const std::uint32_t tail = tail_.load(std::memory_order_acquire);
  return head - tail;
}

void ByteQueue::clear() {
  const std::uint32_t head = head_.load(std::memory_order_acquire);
  tail_.store(head, std::memory_order_release);
}

} // namespace dosey
