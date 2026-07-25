#if defined(DOSEY_TEST_PARSER)

#include <cstring>

#include <unity.h>

#include "command_parser.h"
#include "protocol_writer.h"

using namespace dosey;

void setUp() {}
void tearDown() {}

void test_parses_supported_command_and_id() {
  const ParseResult result = parseCommand("D1 CMD test-001 STATUS");

  TEST_ASSERT_TRUE(result.ok);
  TEST_ASSERT_EQUAL(CommandType::status, result.command.type);
  TEST_ASSERT_EQUAL_STRING("test-001", result.command.id);
}

void test_trims_line_ending() {
  const ParseResult result = parseCommand("D1 CMD test-002 HEARTBEAT\r\n");

  TEST_ASSERT_TRUE(result.ok);
  TEST_ASSERT_EQUAL(CommandType::heartbeat, result.command.type);
}

void test_rejects_unknown_version() {
  const ParseResult result = parseCommand("D2 CMD test-003 STATUS");

  TEST_ASSERT_FALSE(result.ok);
  TEST_ASSERT_EQUAL(ParseError::unsupportedVersion, result.error);
}

void test_rejects_malformed_command() {
  const ParseResult result = parseCommand("D1 STATUS");

  TEST_ASSERT_FALSE(result.ok);
  TEST_ASSERT_EQUAL(ParseError::malformed, result.error);
}

void test_rejects_invalid_command_id() {
  const ParseResult result = parseCommand("D1 CMD bad$id STATUS");

  TEST_ASSERT_FALSE(result.ok);
  TEST_ASSERT_EQUAL(ParseError::invalidId, result.error);
}

void test_rejects_oversized_command_id() {
  const ParseResult result =
      parseCommand("D1 CMD 1234567890123456789012345 STATUS");

  TEST_ASSERT_FALSE(result.ok);
  TEST_ASSERT_EQUAL(ParseError::invalidId, result.error);
}

void test_rejects_oversized_line() {
  char line[kMaxProtocolLineLength + 2];
  std::memset(line, 'A', sizeof(line) - 1);
  line[sizeof(line) - 1] = '\0';

  const ParseResult result = parseCommand(line);

  TEST_ASSERT_FALSE(result.ok);
  TEST_ASSERT_EQUAL(ParseError::lineTooLong, result.error);
}

void test_rejects_unknown_command() {
  const ParseResult result = parseCommand("D1 CMD test-004 SPIN_FOREVER");

  TEST_ASSERT_FALSE(result.ok);
  TEST_ASSERT_EQUAL(ParseError::unknownCommand, result.error);
}

void test_recognizes_disabled_dispense_next() {
  const ParseResult result = parseCommand("D1 CMD test-005 DISPENSE_NEXT");

  TEST_ASSERT_TRUE(result.ok);
  TEST_ASSERT_EQUAL(CommandType::dispenseNext, result.command.type);
}

void test_writes_event_line() {
  char line[kMaxProtocolLineLength + 1];

  TEST_ASSERT_TRUE(
      writeEvent(line, sizeof(line), "test-006", "COMMAND_RECEIVED"));
  TEST_ASSERT_EQUAL_STRING("D1 EVT test-006 COMMAND_RECEIVED", line);
}

void test_writes_nack_line() {
  char line[kMaxProtocolLineLength + 1];

  TEST_ASSERT_TRUE(writeNack(line, sizeof(line), "test-007", "BUSY"));
  TEST_ASSERT_EQUAL_STRING("D1 NACK test-007 BUSY", line);
}

void test_writes_error_line() {
  char line[kMaxProtocolLineLength + 1];

  TEST_ASSERT_TRUE(
      writeError(line, sizeof(line), "test-008", "MOVEMENT_TIMEOUT"));
  TEST_ASSERT_EQUAL_STRING("D1 ERROR test-008 MOVEMENT_TIMEOUT", line);
}

void test_rejects_protocol_output_that_does_not_fit() {
  char line[12];

  TEST_ASSERT_FALSE(
      writeEvent(line, sizeof(line), "test-009", "COMMAND_RECEIVED"));
  TEST_ASSERT_EQUAL_STRING("", line);
}

int main(int argc, char **argv) {
  UNITY_BEGIN();
  RUN_TEST(test_parses_supported_command_and_id);
  RUN_TEST(test_trims_line_ending);
  RUN_TEST(test_rejects_unknown_version);
  RUN_TEST(test_rejects_malformed_command);
  RUN_TEST(test_rejects_invalid_command_id);
  RUN_TEST(test_rejects_oversized_command_id);
  RUN_TEST(test_rejects_oversized_line);
  RUN_TEST(test_rejects_unknown_command);
  RUN_TEST(test_recognizes_disabled_dispense_next);
  RUN_TEST(test_writes_event_line);
  RUN_TEST(test_writes_nack_line);
  RUN_TEST(test_writes_error_line);
  RUN_TEST(test_rejects_protocol_output_that_does_not_fit);
  return UNITY_END();
}

#endif
