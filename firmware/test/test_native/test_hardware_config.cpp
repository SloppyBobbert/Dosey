#if defined(DOSEY_TEST_CONFIG) || defined(DOSEY_TEST_CONFIG_DEFAULTS)

#include <unity.h>

#include "grove_base_pins.h"
#include "hardware_config.h"
#include "servo_pwm_driver.h"

void setUp() {}
void tearDown() {}

#if defined(DOSEY_TEST_CONFIG)
namespace {

struct FakePwm {
  bool attachResult = true;
  bool writeResult = true;
  bool detachResult = true;
  int attachCalls = 0;
  int writeCalls = 0;
  int detachCalls = 0;
  int lastPin = -1;
  std::uint32_t lastDuty = 0;

  bool attach(int pin, int frequencyHz, int resolutionBits) {
    ++attachCalls;
    lastPin = pin;
    TEST_ASSERT_EQUAL(50, frequencyHz);
    TEST_ASSERT_EQUAL(14, resolutionBits);
    return attachResult;
  }

  bool write(int pin, std::uint32_t duty) {
    ++writeCalls;
    lastPin = pin;
    lastDuty = duty;
    return writeResult;
  }

  bool detach(int pin) {
    ++detachCalls;
    lastPin = pin;
    return detachResult;
  }
};

} // namespace

void test_servo_pwm_attaches_once_and_converts_pulse_width() {
  FakePwm pwm;
  dosey::hardware::ServoPwmDriver<FakePwm> servo(pwm);

  TEST_ASSERT_TRUE(servo.attach(19));
  TEST_ASSERT_EQUAL(1, pwm.attachCalls);

  servo.writeMicroseconds(1500);
  TEST_ASSERT_EQUAL(1, pwm.writeCalls);
  TEST_ASSERT_UINT32_WITHIN(1, 1229, pwm.lastDuty);

  servo.detach();
  TEST_ASSERT_EQUAL(1, pwm.detachCalls);
}

void test_servo_pwm_rejects_failed_attachment() {
  FakePwm pwm;
  pwm.attachResult = false;
  dosey::hardware::ServoPwmDriver<FakePwm> servo(pwm);

  TEST_ASSERT_FALSE(servo.attach(19));
  servo.writeMicroseconds(1500);
  servo.detach();

  TEST_ASSERT_EQUAL(1, pwm.attachCalls);
  TEST_ASSERT_EQUAL(0, pwm.writeCalls);
  TEST_ASSERT_EQUAL(0, pwm.detachCalls);
}

void test_servo_pwm_reports_failed_write() {
  FakePwm pwm;
  pwm.writeResult = false;
  dosey::hardware::ServoPwmDriver<FakePwm> servo(pwm);

  TEST_ASSERT_TRUE(servo.attach(19));
  TEST_ASSERT_FALSE(servo.writeMicroseconds(1500));
  TEST_ASSERT_EQUAL(1, pwm.writeCalls);
}

void test_servo_pwm_keeps_attachment_when_detach_fails() {
  FakePwm pwm;
  pwm.detachResult = false;
  dosey::hardware::ServoPwmDriver<FakePwm> servo(pwm);

  TEST_ASSERT_TRUE(servo.attach(19));
  TEST_ASSERT_FALSE(servo.detach());
  pwm.detachResult = true;
  TEST_ASSERT_TRUE(servo.detach());
  TEST_ASSERT_EQUAL(2, pwm.detachCalls);
}

void test_servo_pwm_rejects_reattachment_without_second_hal_attach() {
  FakePwm pwm;
  dosey::hardware::ServoPwmDriver<FakePwm> servo(pwm);

  TEST_ASSERT_TRUE(servo.attach(19));
  TEST_ASSERT_FALSE(servo.attach(19));
  TEST_ASSERT_EQUAL(1, pwm.attachCalls);
}

void test_grove_base_profile_matches_selected_hardware_layout() {
  TEST_ASSERT_EQUAL(0, dosey::hardware::grove_base::kMiniPirPin);
  TEST_ASSERT_EQUAL(1, dosey::hardware::grove_base::kLightSensorPin);
  TEST_ASSERT_EQUAL(2, dosey::hardware::grove_base::kActiveBuzzerPin);
  TEST_ASSERT_EQUAL(22, dosey::hardware::grove_base::kI2cSdaPin);
  TEST_ASSERT_EQUAL(23, dosey::hardware::grove_base::kI2cSclPin);
  TEST_ASSERT_EQUAL(16, dosey::hardware::grove_base::kUartTxPin);
  TEST_ASSERT_EQUAL(17, dosey::hardware::grove_base::kUartRxPin);
  TEST_ASSERT_EQUAL(16, dosey::hardware::grove_base::kFirstButtonFirstPin);
  TEST_ASSERT_EQUAL(17, dosey::hardware::grove_base::kFirstButtonSecondPin);
  TEST_ASSERT_EQUAL(19, dosey::hardware::grove_base::kServoPin);
  TEST_ASSERT_EQUAL(20, dosey::hardware::grove_base::kSecondButtonFirstPin);
  TEST_ASSERT_EQUAL(18, dosey::hardware::grove_base::kSecondButtonSecondPin);
}

void test_enabled_paths_detect_shared_signal_pins() {
  TEST_ASSERT_TRUE(dosey::hardware::enabledPinsConflict(true, 16, true, 16));
  TEST_ASSERT_FALSE(
      dosey::hardware::enabledPinsConflict(true, 16, true, 17));
  TEST_ASSERT_FALSE(
      dosey::hardware::enabledPinsConflict(false, 16, true, 16));
}

void test_all_enabled_paths_must_have_unique_signal_pins() {
  constexpr dosey::hardware::EnabledPin uniquePins[] = {
      {true, 1}, {true, 2}, {false, 2}, {true, 3}};
  constexpr dosey::hardware::EnabledPin conflictingNonServoPins[] = {
      {true, 1}, {true, 2}, {true, 1}};

  TEST_ASSERT_TRUE(dosey::hardware::enabledPinsAreUnique(uniquePins));
  TEST_ASSERT_FALSE(
      dosey::hardware::enabledPinsAreUnique(conflictingNonServoPins));
}

void test_compile_time_overrides_populate_hardware_configuration() {
  TEST_ASSERT_TRUE(dosey::hardware::kDigitalOutputConfigured);
  TEST_ASSERT_EQUAL(1, dosey::hardware::kDigitalOutputPin);
  TEST_ASSERT_TRUE(dosey::hardware::kButtonConfigured);
  TEST_ASSERT_EQUAL(2, dosey::hardware::kButtonPin);
  TEST_ASSERT_TRUE(dosey::hardware::kPirConfigured);
  TEST_ASSERT_EQUAL(3, dosey::hardware::kPirPin);
  TEST_ASSERT_TRUE(dosey::hardware::kPirWakeEnabled);
  TEST_ASSERT_FALSE(dosey::hardware::kPirActiveHigh);
  TEST_ASSERT_TRUE(dosey::hardware::kAnalogInputConfigured);
  TEST_ASSERT_EQUAL(4, dosey::hardware::kAnalogInputPin);
  TEST_ASSERT_TRUE(dosey::hardware::kI2cConfigured);
  TEST_ASSERT_EQUAL(5, dosey::hardware::kI2cSdaPin);
  TEST_ASSERT_EQUAL(6, dosey::hardware::kI2cSclPin);
  TEST_ASSERT_TRUE(dosey::hardware::kGroveDiagnosticsEnabled);
  TEST_ASSERT_TRUE(dosey::hardware::kServoEnabled);
  TEST_ASSERT_EQUAL(7, dosey::hardware::kServoPin);
}
#endif

#if defined(DOSEY_TEST_CONFIG_DEFAULTS)
void test_external_hardware_defaults_remain_disabled() {
  TEST_ASSERT_FALSE(dosey::hardware::kDigitalOutputConfigured);
  TEST_ASSERT_EQUAL(-1, dosey::hardware::kDigitalOutputPin);
  TEST_ASSERT_FALSE(dosey::hardware::kButtonConfigured);
  TEST_ASSERT_EQUAL(-1, dosey::hardware::kButtonPin);
  TEST_ASSERT_FALSE(dosey::hardware::kPirConfigured);
  TEST_ASSERT_EQUAL(-1, dosey::hardware::kPirPin);
  TEST_ASSERT_FALSE(dosey::hardware::kPirWakeEnabled);
  TEST_ASSERT_FALSE(dosey::hardware::kAnalogInputConfigured);
  TEST_ASSERT_EQUAL(-1, dosey::hardware::kAnalogInputPin);
  TEST_ASSERT_FALSE(dosey::hardware::kI2cConfigured);
  TEST_ASSERT_EQUAL(-1, dosey::hardware::kI2cSdaPin);
  TEST_ASSERT_EQUAL(-1, dosey::hardware::kI2cSclPin);
  TEST_ASSERT_FALSE(dosey::hardware::kGroveDiagnosticsEnabled);
  TEST_ASSERT_FALSE(dosey::hardware::kServoEnabled);
  TEST_ASSERT_EQUAL(-1, dosey::hardware::kServoPin);
}
#endif

int main(int argc, char **argv) {
  UNITY_BEGIN();
#if defined(DOSEY_TEST_CONFIG)
  RUN_TEST(test_servo_pwm_attaches_once_and_converts_pulse_width);
  RUN_TEST(test_servo_pwm_rejects_failed_attachment);
  RUN_TEST(test_servo_pwm_reports_failed_write);
  RUN_TEST(test_servo_pwm_keeps_attachment_when_detach_fails);
  RUN_TEST(test_servo_pwm_rejects_reattachment_without_second_hal_attach);
  RUN_TEST(test_grove_base_profile_matches_selected_hardware_layout);
  RUN_TEST(test_enabled_paths_detect_shared_signal_pins);
  RUN_TEST(test_all_enabled_paths_must_have_unique_signal_pins);
  RUN_TEST(test_compile_time_overrides_populate_hardware_configuration);
#else
  RUN_TEST(test_external_hardware_defaults_remain_disabled);
#endif
  return UNITY_END();
}

#endif
