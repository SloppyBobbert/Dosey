#if defined(DOSEY_TEST_PROTOCOL)

#include <initializer_list>
#include <string>
#include <vector>

#include <unity.h>

#include "byte_queue.h"
#include "debug_event_observer.h"
#include "line_accumulator.h"
#include "protocol_engine.h"
#include "safety_limits.h"

using namespace dosey;

#if defined(DOSEY_TEST_PROTOCOL_DEBUG)
constexpr const char *kExpectedDebugAvailabilityLine =
    "D1 EVT status-1 DEBUG_AVAILABLE";
#else
constexpr const char *kExpectedDebugAvailabilityLine =
    "D1 EVT status-1 DEBUG_UNAVAILABLE";
#endif

void setUp() {}
void tearDown() {}

class CapturingOutput final : public ProtocolOutput {
public:
  bool writeLine(const char *line) override {
    if (!acceptWrites) {
      return false;
    }
    lines.emplace_back(line);
    return true;
  }

  bool acceptWrites = true;
  std::vector<std::string> lines;
};

class FakeHardware final : public ProtocolHardware {
public:
  bool servoConfigured() const override { return servoIsConfigured; }
  bool pirConfigured() const override { return pirIsConfigured; }
  bool pirMotion() const override { return pirHasMotion; }

  void setLedActive(bool active) override { ledActive = active; }

  bool startMovement(std::uint32_t) override {
    ++movementStarts;
    return movementStartsSuccessfully;
  }

  void stopMovement() override { ++movementStops; }

  HardwareMovementUpdate updateMovement(std::uint32_t) override {
    const HardwareMovementUpdate result = nextMovementUpdate;
    nextMovementUpdate = HardwareMovementUpdate::none;
    return result;
  }

  bool servoIsConfigured = false;
  bool pirIsConfigured = false;
  bool pirHasMotion = false;
  bool ledActive = false;
  bool movementStartsSuccessfully = true;
  int movementStarts = 0;
  int movementStops = 0;
  HardwareMovementUpdate nextMovementUpdate = HardwareMovementUpdate::none;
};

void assertLines(const CapturingOutput &output,
                 std::initializer_list<const char *> expected) {
  TEST_ASSERT_EQUAL(expected.size(), output.lines.size());
  std::size_t index = 0;
  for (const char *line : expected) {
    TEST_ASSERT_EQUAL_STRING(line, output.lines[index].c_str());
    ++index;
  }
}

void test_waits_for_newline_before_returning_line() {
  LineAccumulator input;

  TEST_ASSERT_EQUAL(LineResult::pending, input.push('D'));
  TEST_ASSERT_EQUAL(LineResult::pending, input.push('1'));
  TEST_ASSERT_EQUAL(LineResult::lineReady, input.push('\n'));
  TEST_ASSERT_EQUAL_STRING("D1", input.line());
}

void test_accepts_multiple_lines_after_reset() {
  LineAccumulator input;

  for (const char character : {'O', 'N', 'E', '\n'}) {
    input.push(character);
  }
  TEST_ASSERT_EQUAL_STRING("ONE", input.line());

  for (const char character : {'T', 'W', 'O', '\n'}) {
    input.push(character);
  }
  TEST_ASSERT_EQUAL_STRING("TWO", input.line());
}

void test_reports_oversized_line_and_recovers_at_newline() {
  LineAccumulator input;

  for (std::size_t index = 0; index <= kMaxProtocolLineLength; ++index) {
    TEST_ASSERT_EQUAL(LineResult::pending, input.push('A'));
  }
  TEST_ASSERT_EQUAL(LineResult::lineTooLong, input.push('\n'));

  TEST_ASSERT_EQUAL(LineResult::pending, input.push('O'));
  TEST_ASSERT_EQUAL(LineResult::pending, input.push('K'));
  TEST_ASSERT_EQUAL(LineResult::lineReady, input.push('\n'));
  TEST_ASSERT_EQUAL_STRING("OK", input.line());
}

void test_keeps_carriage_return_for_parser_validation() {
  LineAccumulator input;

  for (const char character : {'O', 'K', '\r', '\n'}) {
    input.push(character);
  }

  TEST_ASSERT_EQUAL_STRING("OK\r", input.line());
}

void test_line_accumulator_can_discard_partial_transport_input() {
  LineAccumulator input;

  input.push('B');
  input.push('A');
  input.reset();
  input.push('O');
  input.push('K');
  TEST_ASSERT_EQUAL(LineResult::lineReady, input.push('\n'));

  TEST_ASSERT_EQUAL_STRING("OK", input.line());
}

void test_line_accumulator_rejects_invalid_bytes_and_recovers() {
  for (const char invalid : {'\0', '\t', static_cast<char>(0x80)}) {
    LineAccumulator input;
    TEST_ASSERT_EQUAL(LineResult::pending, input.push('D'));
    TEST_ASSERT_EQUAL(LineResult::pending, input.push(invalid));
    TEST_ASSERT_EQUAL(LineResult::pending, input.push('1'));
    TEST_ASSERT_EQUAL(LineResult::lineInvalid, input.push('\n'));

    TEST_ASSERT_EQUAL(LineResult::pending, input.push('O'));
    TEST_ASSERT_EQUAL(LineResult::pending, input.push('K'));
    TEST_ASSERT_EQUAL(LineResult::lineReady, input.push('\n'));
    TEST_ASSERT_EQUAL_STRING("OK", input.line());
  }
}

void test_byte_queue_preserves_fragmented_input_order() {
  ByteQueue input;
  const std::uint8_t first[] = {'D', '1', ' '};
  const std::uint8_t second[] = {'C', 'M', 'D', '\n'};

  TEST_ASSERT_TRUE(input.push(first, sizeof(first)));
  TEST_ASSERT_TRUE(input.push(second, sizeof(second)));

  char value = '\0';
  std::string received;
  while (input.pop(value)) {
    received.push_back(value);
  }
  TEST_ASSERT_EQUAL_STRING("D1 CMD\n", received.c_str());
}

void test_byte_queue_rejects_overflow_without_partial_write() {
  ByteQueue input;
  std::uint8_t full[kBleByteQueueCapacity] = {};
  const std::uint8_t overflow[] = {'N', 'O'};

  TEST_ASSERT_TRUE(input.push(full, sizeof(full)));
  TEST_ASSERT_FALSE(input.push(overflow, sizeof(overflow)));
  TEST_ASSERT_EQUAL(kBleByteQueueCapacity, input.size());
}

void test_debug_event_observer_only_accepts_terminal_d1_toggle_events() {
  TEST_ASSERT_EQUAL(DebugOutputState::enabled,
                    debugOutputState("D1 EVT debug-1 DEBUG_ON"));
  TEST_ASSERT_EQUAL(DebugOutputState::disabled,
                    debugOutputState("D1 EVT debug-2 DEBUG_OFF"));
  TEST_ASSERT_EQUAL(DebugOutputState::unchanged,
                    debugOutputState("D1 CMD debug-1 DEBUG_ON"));
  TEST_ASSERT_EQUAL(DebugOutputState::unchanged,
                    debugOutputState("D1 EVT debug-1 DEBUG_ON EXTRA"));
  TEST_ASSERT_EQUAL(DebugOutputState::unchanged,
                    debugOutputState("D1 EVT status-1 MOVEMENT_IDLE"));
  TEST_ASSERT_EQUAL(DebugOutputState::unchanged, debugOutputState(nullptr));
}

void test_status_reports_capabilities_and_idle_state() {
  FakeHardware hardware;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 CMD status-1 STATUS", 100);

  assertLines(output,
               {"D1 EVT status-1 COMMAND_RECEIVED", "D1 EVT status-1 STATUS_OK",
                "D1 EVT status-1 SERVO_UNCONFIGURED",
                "D1 EVT status-1 PIR_UNCONFIGURED",
                kExpectedDebugAvailabilityLine,
                "D1 EVT status-1 DEBUG_OFF",
                "D1 EVT status-1 MOVEMENT_IDLE"});
}

void test_status_reports_active_movement() {
  FakeHardware hardware;
  hardware.servoIsConfigured = true;
  hardware.pirIsConfigured = true;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 CMD move-1 SERVO_TEST", 100);
  output.lines.clear();
  engine.handleLine("D1 CMD status-1 STATUS", 101);

  assertLines(output,
               {"D1 EVT status-1 COMMAND_RECEIVED", "D1 EVT status-1 STATUS_OK",
                "D1 EVT status-1 SERVO_CONFIGURED",
                "D1 EVT status-1 PIR_CONFIGURED",
                kExpectedDebugAvailabilityLine,
                "D1 EVT status-1 DEBUG_OFF",
                "D1 EVT status-1 MOVEMENT_ACTIVE"});
}

void test_heartbeat_has_exact_transcript() {
  FakeHardware hardware;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 CMD beat-1 HEARTBEAT", 100);

  assertLines(output,
              {"D1 EVT beat-1 COMMAND_RECEIVED", "D1 EVT beat-1 HEARTBEAT_OK"});
}

void test_device_info_reports_stable_identity() {
  FakeHardware hardware;
  CapturingOutput output;
  ProtocolEngine protocol(hardware, output);

  protocol.handleLine("D1 CMD info-1 DEVICE_INFO", 0);

  assertLines(output, {"D1 EVT info-1 COMMAND_RECEIVED",
                       "D1 EVT info-1 DEVICE_INFO_OK",
                       "D1 EVT info-1 FIRMWARE_DOSEY_CONTROLLER",
                       "D1 EVT info-1 PROTOCOL_D1",
                       "D1 EVT info-1 BOARD_XIAO_ESP32_C6_EXPANSION",
#if defined(DOSEY_TEST_PROTOCOL_DEBUG)
                       "D1 EVT info-1 BUILD_DEBUG"});
#else
                       "D1 EVT info-1 BUILD_BASELINE"});
#endif
}

void test_config_status_reports_safe_default_profile() {
  FakeHardware hardware;
  CapturingOutput output;
  ProtocolEngine protocol(hardware, output);

  protocol.handleLine("D1 CMD config-1 CONFIG_STATUS", 0);

  assertLines(output, {"D1 EVT config-1 COMMAND_RECEIVED",
                       "D1 EVT config-1 CONFIG_STATUS_OK",
                       "D1 EVT config-1 SERVO_DISABLED",
                       "D1 EVT config-1 PIR_DISABLED",
                       "D1 EVT config-1 I2C_DISABLED",
                       "D1 EVT config-1 BUTTON_DISABLED",
                       "D1 EVT config-1 UART_RESERVED_SERVO_D6_PROFILE"});
}

void test_safety_status_reports_compiled_limits_and_disabled_dispense() {
  FakeHardware hardware;
  CapturingOutput output;
  ProtocolEngine protocol(hardware, output);

  protocol.handleLine("D1 CMD safety-1 SAFETY_STATUS", 0);

  assertLines(output, {"D1 EVT safety-1 COMMAND_RECEIVED",
                       "D1 EVT safety-1 SAFETY_STATUS_OK",
                       "D1 EVT safety-1 MOVEMENT_TIMEOUT_MS_2500",
                       "D1 EVT safety-1 SERVO_PULSE_US_1000_2000",
                       "D1 EVT safety-1 SERVO_ANGLES_DEG_90_100",
                       "D1 EVT safety-1 DISPENSE_NEXT_DISABLED"});
  TEST_ASSERT_EQUAL(0, hardware.movementStarts);
  TEST_ASSERT_EQUAL(0, hardware.movementStops);
}

void test_debug_commands_are_disabled_without_debug_capability() {
  FakeHardware hardware;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 CMD debug-1 DEBUG_ON", 100);
  engine.handleLine("D1 CMD debug-2 DEBUG_OFF", 101);

  assertLines(output, {"D1 NACK debug-1 COMMAND_DISABLED",
                       "D1 NACK debug-2 COMMAND_DISABLED"});
}

#if defined(DOSEY_TEST_PROTOCOL_DEBUG)
void test_debug_commands_toggle_volatile_debug_state() {
  FakeHardware hardware;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 CMD debug-1 DEBUG_ON", 100);
  engine.handleLine("D1 CMD status-1 STATUS", 101);
  engine.handleLine("D1 CMD debug-2 DEBUG_OFF", 102);

  assertLines(
      output,
      {"D1 EVT debug-1 COMMAND_RECEIVED", "D1 EVT debug-1 DEBUG_ON",
       "D1 EVT status-1 COMMAND_RECEIVED", "D1 EVT status-1 STATUS_OK",
       "D1 EVT status-1 SERVO_UNCONFIGURED",
       "D1 EVT status-1 PIR_UNCONFIGURED",
       "D1 EVT status-1 DEBUG_AVAILABLE", "D1 EVT status-1 DEBUG_ON",
       "D1 EVT status-1 MOVEMENT_IDLE", "D1 EVT debug-2 COMMAND_RECEIVED",
       "D1 EVT debug-2 DEBUG_OFF"});
}
#endif

void test_led_test_rejects_overlap_and_finishes_at_deadline() {
  FakeHardware hardware;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 CMD led-1 LED_TEST", 100);
  engine.handleLine("D1 CMD led-2 LED_TEST", 101);
  engine.update(100 + safety::kLedTestDurationMs - 1);
  TEST_ASSERT_TRUE(hardware.ledActive);
  engine.update(100 + safety::kLedTestDurationMs);

  assertLines(output,
              {"D1 EVT led-1 COMMAND_RECEIVED", "D1 EVT led-1 LED_TEST_STARTED",
               "D1 NACK led-2 BUSY", "D1 EVT led-1 LED_TEST_DONE"});
  TEST_ASSERT_FALSE(hardware.ledActive);
}

void test_led_deadline_handles_timer_wraparound() {
  FakeHardware hardware;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);
  const std::uint32_t start = UINT32_MAX - 100;

  engine.handleLine("D1 CMD led-wrap LED_TEST", start);
  engine.update(start + safety::kLedTestDurationMs);

  TEST_ASSERT_FALSE(hardware.ledActive);
  TEST_ASSERT_EQUAL_STRING("D1 EVT led-wrap LED_TEST_DONE",
                           output.lines.back().c_str());
}

void test_unconfigured_commands_and_dispense_next_are_rejected() {
  FakeHardware hardware;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 CMD pir-1 PIR_STATUS", 100);
  engine.handleLine("D1 CMD servo-1 SERVO_TEST", 100);
  engine.handleLine("D1 CMD test-1 DISPENSE_TEST", 100);
  engine.handleLine("D1 CMD dose-1 DISPENSE_NEXT", 100);

  assertLines(output, {"D1 NACK pir-1 CONFIGURATION_REQUIRED",
                       "D1 NACK servo-1 CONFIGURATION_REQUIRED",
                       "D1 NACK test-1 CONFIGURATION_REQUIRED",
                       "D1 NACK dose-1 COMMAND_DISABLED"});
}

void test_pir_reports_current_input_when_configured() {
  FakeHardware hardware;
  hardware.pirIsConfigured = true;
  hardware.pirHasMotion = true;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 CMD pir-1 PIR_STATUS", 100);

  assertLines(output,
              {"D1 EVT pir-1 COMMAND_RECEIVED", "D1 EVT pir-1 PIR_MOTION"});
}

void test_movement_rejects_duplicate_and_overlapping_commands() {
  FakeHardware hardware;
  hardware.servoIsConfigured = true;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 CMD move-1 SERVO_TEST", 100);
  engine.handleLine("D1 CMD move-1 SERVO_TEST", 101);
  engine.handleLine("D1 CMD move-2 DISPENSE_TEST", 102);

  assertLines(output,
              {"D1 EVT move-1 COMMAND_RECEIVED",
               "D1 EVT move-1 MOVEMENT_STARTED",
               "D1 NACK move-1 DUPLICATE_ACTIVE_ID", "D1 NACK move-2 BUSY"});
  TEST_ASSERT_EQUAL(1, hardware.movementStarts);
}

void test_movement_does_not_start_when_acceptance_cannot_be_written() {
  FakeHardware hardware;
  hardware.servoIsConfigured = true;
  CapturingOutput output;
  output.acceptWrites = false;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 CMD move-1 SERVO_TEST", 100);

  TEST_ASSERT_EQUAL(0, hardware.movementStarts);
  TEST_ASSERT_EQUAL(1, hardware.movementStops);
  output.acceptWrites = true;
  engine.handleLine("D1 CMD move-2 SERVO_TEST", 101);
  TEST_ASSERT_EQUAL(1, hardware.movementStarts);
}

void test_cancel_stops_active_movement_as_unresolved() {
  FakeHardware hardware;
  hardware.servoIsConfigured = true;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 CMD move-1 SERVO_TEST", 100);
  engine.handleLine("D1 CMD cancel-1 CANCEL", 101);

  TEST_ASSERT_EQUAL_STRING("D1 EVT cancel-1 COMMAND_RECEIVED",
                           output.lines[2].c_str());
  TEST_ASSERT_EQUAL_STRING("D1 EVT move-1 MOVEMENT_CANCELLED_UNRESOLVED",
                           output.lines[3].c_str());
  TEST_ASSERT_EQUAL(1, hardware.movementStops);
}

void test_transport_disconnect_stops_active_movement_without_completion() {
  FakeHardware hardware;
  hardware.servoIsConfigured = true;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 CMD move-1 SERVO_TEST", 100);
  engine.handleTransportDisconnect();
  output.lines.clear();
  engine.handleLine("D1 CMD status-1 STATUS", 101);

  TEST_ASSERT_EQUAL(1, hardware.movementStops);
  TEST_ASSERT_EQUAL_STRING("D1 EVT status-1 MOVEMENT_IDLE",
                           output.lines.back().c_str());
}

void test_hardware_completion_reports_servo_done() {
  FakeHardware hardware;
  hardware.servoIsConfigured = true;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 CMD move-1 DISPENSE_TEST", 100);
  hardware.nextMovementUpdate = HardwareMovementUpdate::completed;
  engine.update(101);

  TEST_ASSERT_EQUAL_STRING("D1 EVT move-1 SERVO_DONE",
                           output.lines.back().c_str());
  TEST_ASSERT_EQUAL(1, hardware.movementStops);
}

void test_movement_timeout_stops_hardware_and_remains_unresolved() {
  FakeHardware hardware;
  hardware.servoIsConfigured = true;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 CMD move-1 DISPENSE_TEST", 100);
  engine.update(100 + safety::kMovementTimeoutMs);

  TEST_ASSERT_EQUAL_STRING("D1 ERROR move-1 MOVEMENT_TIMEOUT",
                           output.lines.back().c_str());
  TEST_ASSERT_EQUAL(1, hardware.movementStops);
}

void test_failed_servo_start_reports_error_without_movement_started() {
  FakeHardware hardware;
  hardware.servoIsConfigured = true;
  hardware.movementStartsSuccessfully = false;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 CMD move-1 SERVO_TEST", 100);

  assertLines(output, {"D1 EVT move-1 COMMAND_RECEIVED",
                       "D1 ERROR move-1 SERVO_ATTACH_FAILED"});
  TEST_ASSERT_EQUAL(1, hardware.movementStops);
}

void test_malformed_and_oversized_input_use_untrusted_id() {
  FakeHardware hardware;
  CapturingOutput output;
  ProtocolEngine engine(hardware, output);

  engine.handleLine("D1 STATUS", 100);
  engine.handleLineTooLong();

  assertLines(output,
              {"D1 NACK none MALFORMED_COMMAND", "D1 NACK none LINE_TOO_LONG"});
}

int main(int argc, char **argv) {
  UNITY_BEGIN();
  RUN_TEST(test_waits_for_newline_before_returning_line);
  RUN_TEST(test_accepts_multiple_lines_after_reset);
  RUN_TEST(test_reports_oversized_line_and_recovers_at_newline);
  RUN_TEST(test_keeps_carriage_return_for_parser_validation);
  RUN_TEST(test_line_accumulator_can_discard_partial_transport_input);
  RUN_TEST(test_line_accumulator_rejects_invalid_bytes_and_recovers);
  RUN_TEST(test_byte_queue_preserves_fragmented_input_order);
  RUN_TEST(test_byte_queue_rejects_overflow_without_partial_write);
  RUN_TEST(test_debug_event_observer_only_accepts_terminal_d1_toggle_events);
  RUN_TEST(test_status_reports_capabilities_and_idle_state);
  RUN_TEST(test_status_reports_active_movement);
  RUN_TEST(test_heartbeat_has_exact_transcript);
  RUN_TEST(test_device_info_reports_stable_identity);
  RUN_TEST(test_config_status_reports_safe_default_profile);
  RUN_TEST(test_safety_status_reports_compiled_limits_and_disabled_dispense);
#if defined(DOSEY_TEST_PROTOCOL_DEBUG)
  RUN_TEST(test_debug_commands_toggle_volatile_debug_state);
#else
  RUN_TEST(test_debug_commands_are_disabled_without_debug_capability);
#endif
  RUN_TEST(test_led_test_rejects_overlap_and_finishes_at_deadline);
  RUN_TEST(test_led_deadline_handles_timer_wraparound);
  RUN_TEST(test_unconfigured_commands_and_dispense_next_are_rejected);
  RUN_TEST(test_pir_reports_current_input_when_configured);
  RUN_TEST(test_movement_rejects_duplicate_and_overlapping_commands);
  RUN_TEST(test_movement_does_not_start_when_acceptance_cannot_be_written);
  RUN_TEST(test_cancel_stops_active_movement_as_unresolved);
  RUN_TEST(test_transport_disconnect_stops_active_movement_without_completion);
  RUN_TEST(test_hardware_completion_reports_servo_done);
  RUN_TEST(test_movement_timeout_stops_hardware_and_remains_unresolved);
  RUN_TEST(test_failed_servo_start_reports_error_without_movement_started);
  RUN_TEST(test_malformed_and_oversized_input_use_untrusted_id);
  return UNITY_END();
}

#endif
