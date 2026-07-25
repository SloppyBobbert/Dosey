#if defined(DOSEY_TEST_STATE)

#include <unity.h>

#include "controller_state.h"

using namespace dosey;

void setUp() {}
void tearDown() {}

void test_accepts_one_movement_and_rejects_overlap() {
  ControllerState state;

  TEST_ASSERT_EQUAL(AcceptResult::accepted,
                    state.acceptMovement("move-001", 1000, 500));
  TEST_ASSERT_EQUAL(AcceptResult::busy,
                    state.acceptMovement("move-002", 1001, 500));
  TEST_ASSERT_TRUE(state.isMoving());
  TEST_ASSERT_EQUAL_STRING("move-001", state.activeCommandId());
}

void test_rejects_duplicate_active_id() {
  ControllerState state;
  state.acceptMovement("move-001", 1000, 500);

  TEST_ASSERT_EQUAL(AcceptResult::duplicateId,
                    state.acceptMovement("move-001", 1001, 500));
}

void test_completes_active_movement() {
  ControllerState state;
  state.acceptMovement("move-001", 1000, 500);

  TEST_ASSERT_EQUAL(MovementResult::completed, state.completeMovement());
  TEST_ASSERT_FALSE(state.isMoving());
  TEST_ASSERT_EQUAL(MovementOutcome::completed, state.lastOutcome());
}

void test_cancel_stops_movement_as_unresolved() {
  ControllerState state;
  state.acceptMovement("move-001", 1000, 500);

  TEST_ASSERT_EQUAL(MovementResult::cancelled, state.cancelMovement());
  TEST_ASSERT_FALSE(state.isMoving());
  TEST_ASSERT_EQUAL(MovementOutcome::cancelledUnresolved, state.lastOutcome());
}

void test_timeout_stops_movement_as_unresolved() {
  ControllerState state;
  state.acceptMovement("move-001", 1000, 500);

  TEST_ASSERT_EQUAL(MovementResult::none, state.update(1499));
  TEST_ASSERT_EQUAL(MovementResult::timedOut, state.update(1500));
  TEST_ASSERT_FALSE(state.isMoving());
  TEST_ASSERT_EQUAL(MovementOutcome::timedOutUnresolved, state.lastOutcome());
}

void test_idle_cancel_does_nothing() {
  ControllerState state;

  TEST_ASSERT_EQUAL(MovementResult::notMoving, state.cancelMovement());
}

int main(int argc, char **argv) {
  UNITY_BEGIN();
  RUN_TEST(test_accepts_one_movement_and_rejects_overlap);
  RUN_TEST(test_rejects_duplicate_active_id);
  RUN_TEST(test_completes_active_movement);
  RUN_TEST(test_cancel_stops_movement_as_unresolved);
  RUN_TEST(test_timeout_stops_movement_as_unresolved);
  RUN_TEST(test_idle_cancel_does_nothing);
  return UNITY_END();
}

#endif
