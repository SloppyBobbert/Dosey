#if defined(DOSEY_TEST_CONFIG) || defined(DOSEY_TEST_CONFIG_DEFAULTS)

#include <unity.h>

#include "hardware_config.h"

void setUp() {}
void tearDown() {}

#if defined(DOSEY_TEST_CONFIG)
void test_compile_time_overrides_populate_hardware_configuration() {
  TEST_ASSERT_TRUE(dosey::hardware::kDigitalOutputConfigured);
  TEST_ASSERT_EQUAL(1, dosey::hardware::kDigitalOutputPin);
  TEST_ASSERT_TRUE(dosey::hardware::kButtonConfigured);
  TEST_ASSERT_EQUAL(2, dosey::hardware::kButtonPin);
  TEST_ASSERT_TRUE(dosey::hardware::kPirConfigured);
  TEST_ASSERT_EQUAL(3, dosey::hardware::kPirPin);
  TEST_ASSERT_TRUE(dosey::hardware::kAnalogInputConfigured);
  TEST_ASSERT_EQUAL(4, dosey::hardware::kAnalogInputPin);
  TEST_ASSERT_TRUE(dosey::hardware::kI2cConfigured);
  TEST_ASSERT_EQUAL(5, dosey::hardware::kI2cSdaPin);
  TEST_ASSERT_EQUAL(6, dosey::hardware::kI2cSclPin);
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
  TEST_ASSERT_FALSE(dosey::hardware::kAnalogInputConfigured);
  TEST_ASSERT_EQUAL(-1, dosey::hardware::kAnalogInputPin);
  TEST_ASSERT_FALSE(dosey::hardware::kI2cConfigured);
  TEST_ASSERT_EQUAL(-1, dosey::hardware::kI2cSdaPin);
  TEST_ASSERT_EQUAL(-1, dosey::hardware::kI2cSclPin);
  TEST_ASSERT_FALSE(dosey::hardware::kServoEnabled);
  TEST_ASSERT_EQUAL(-1, dosey::hardware::kServoPin);
}
#endif

int main(int argc, char **argv) {
  UNITY_BEGIN();
#if defined(DOSEY_TEST_CONFIG)
  RUN_TEST(test_compile_time_overrides_populate_hardware_configuration);
#else
  RUN_TEST(test_external_hardware_defaults_remain_disabled);
#endif
  return UNITY_END();
}

#endif
