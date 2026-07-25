#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <ESP32Servo.h>

#include <atomic>
#include <cstring>

#include "ble_config.h"
#include "byte_queue.h"
#include "hardware_config.h"
#include "line_accumulator.h"
#include "protocol_engine.h"
#include "safety_limits.h"

namespace {

enum class ServoPhase { idle, homeSettling, testSettling, returnSettling };

int inactiveLedLevel() {
  return dosey::hardware::kOnboardLedActiveLow ? HIGH : LOW;
}

int activeLedLevel() {
  return dosey::hardware::kOnboardLedActiveLow ? LOW : HIGH;
}

std::atomic<bool> deviceConnected{false};
std::atomic<bool> disconnectPending{false};
std::atomic<bool> inputOverflow{false};
dosey::ByteQueue inputBytes;
dosey::ByteQueue outputBytes;
BLEServer *bleServer = nullptr;
BLECharacteristic *eventCharacteristic = nullptr;

class BleProtocolOutput final : public dosey::ProtocolOutput {
public:
  void writeLine(const char *line) override {
    if (!deviceConnected.load(std::memory_order_acquire) || line == nullptr) {
      return;
    }

    const std::size_t length = std::strlen(line);
    if (length > dosey::kMaxProtocolLineLength) {
      return;
    }
    std::uint8_t framed[dosey::kMaxProtocolLineLength + 1] = {};
    std::memcpy(framed, line, length);
    framed[length] = '\n';
    if (!outputBytes.push(framed, length + 1)) {
      Serial.println("BLE output queue full; response dropped");
    }
  }
};

class ArduinoProtocolHardware final : public dosey::ProtocolHardware {
public:
  bool servoConfigured() const override {
    return dosey::hardware::kServoEnabled;
  }

  bool pirConfigured() const override {
    return dosey::hardware::kPirConfigured;
  }

  bool pirMotion() const override {
    if constexpr (!dosey::hardware::kPirConfigured) {
      return false;
    }
    return digitalRead(dosey::hardware::kPirPin);
  }

  void setLedActive(bool active) override {
    digitalWrite(dosey::hardware::kOnboardLedPin,
                 active ? activeLedLevel() : inactiveLedLevel());
  }

  bool startMovement(std::uint32_t nowMs) override {
    if constexpr (!dosey::hardware::kServoEnabled) {
      return false;
    }

    servo_.setPeriodHertz(50);
    servo_.attach(dosey::hardware::kServoPin,
                  dosey::safety::kServoMinimumPulseUs,
                  dosey::safety::kServoMaximumPulseUs);
    if (!servo_.attached()) {
      return false;
    }
    servo_.write(dosey::safety::kServoHomeDegrees);
    phase_ = ServoPhase::homeSettling;
    phaseDeadlineMs_ = nowMs + dosey::safety::kServoStepSettleMs;
    return true;
  }

  void stopMovement() override {
    servo_.detach();
    phase_ = ServoPhase::idle;
  }

  dosey::HardwareMovementUpdate updateMovement(std::uint32_t nowMs) override {
    if constexpr (!dosey::hardware::kServoEnabled) {
      return dosey::HardwareMovementUpdate::none;
    }
    if (phase_ == ServoPhase::idle ||
        static_cast<std::int32_t>(nowMs - phaseDeadlineMs_) < 0) {
      return dosey::HardwareMovementUpdate::none;
    }
    if (phase_ == ServoPhase::homeSettling) {
      servo_.write(dosey::safety::kServoTestDegrees);
      phase_ = ServoPhase::testSettling;
      phaseDeadlineMs_ = nowMs + dosey::safety::kServoStepSettleMs;
      return dosey::HardwareMovementUpdate::none;
    }
    if (phase_ == ServoPhase::testSettling) {
      servo_.write(dosey::safety::kServoHomeDegrees);
      phase_ = ServoPhase::returnSettling;
      phaseDeadlineMs_ = nowMs + dosey::safety::kServoStepSettleMs;
      return dosey::HardwareMovementUpdate::none;
    }
    return dosey::HardwareMovementUpdate::completed;
  }

private:
  Servo servo_;
  ServoPhase phase_ = ServoPhase::idle;
  std::uint32_t phaseDeadlineMs_ = 0;
};

class ServerCallbacks final : public BLEServerCallbacks {
  void onConnect(BLEServer *) override {
    deviceConnected.store(true, std::memory_order_release);
  }

  void onDisconnect(BLEServer *) override {
    deviceConnected.store(false, std::memory_order_release);
    disconnectPending.store(true, std::memory_order_release);
  }
};

class CommandCallbacks final : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) override {
    const String value = characteristic->getValue();
    if (value.length() == 0) {
      return;
    }
    if (!inputBytes.push(reinterpret_cast<const std::uint8_t *>(value.c_str()),
                         value.length())) {
      inputOverflow.store(true, std::memory_order_release);
    }
  }
};

dosey::LineAccumulator inputLine;
BleProtocolOutput output;
ArduinoProtocolHardware hardware;
dosey::ProtocolEngine protocol(hardware, output);
ServerCallbacks serverCallbacks;
CommandCallbacks commandCallbacks;

void processConnectionChanges() {
  if (!disconnectPending.exchange(false, std::memory_order_acq_rel)) {
    return;
  }
  protocol.handleTransportDisconnect();
  inputBytes.clear();
  outputBytes.clear();
  inputLine.reset();
  if (!deviceConnected.load(std::memory_order_acquire)) {
    bleServer->startAdvertising();
  }
}

void processInput() {
  if (inputOverflow.exchange(false, std::memory_order_acq_rel)) {
    inputBytes.clear();
    inputLine.reset();
    protocol.handleLineTooLong();
    return;
  }

  char value = '\0';
  while (inputBytes.pop(value)) {
    const dosey::LineResult result = inputLine.push(value);
    if (result == dosey::LineResult::lineReady) {
      protocol.handleLine(inputLine.line(), millis());
    } else if (result == dosey::LineResult::lineTooLong) {
      protocol.handleLineTooLong();
    }
  }
}

void sendNextOutputChunk() {
  if (!deviceConnected.load(std::memory_order_acquire) ||
      eventCharacteristic == nullptr) {
    return;
  }

  std::uint8_t chunk[dosey::ble::kChunkSize] = {};
  std::size_t length = 0;
  char value = '\0';
  while (length < sizeof(chunk) && outputBytes.pop(value)) {
    chunk[length++] = static_cast<std::uint8_t>(value);
  }
  if (length == 0) {
    return;
  }
  eventCharacteristic->setValue(chunk, length);
  eventCharacteristic->notify();
}

} // namespace

void setup() {
  digitalWrite(dosey::hardware::kOnboardLedPin, inactiveLedLevel());
  pinMode(dosey::hardware::kOnboardLedPin, OUTPUT);
  if constexpr (dosey::hardware::kPirConfigured) {
    pinMode(dosey::hardware::kPirPin, INPUT);
  }

  Serial.begin(dosey::safety::kSerialBaud);
  delay(dosey::safety::kSerialStartupWaitMs);

  BLEDevice::init(dosey::ble::kDeviceName);
  bleServer = BLEDevice::createServer();
  bleServer->setCallbacks(&serverCallbacks);
  BLEService *service = bleServer->createService(dosey::ble::kServiceUuid);
  eventCharacteristic = service->createCharacteristic(
      dosey::ble::kEventCharacteristicUuid, BLECharacteristic::PROPERTY_NOTIFY);
  BLECharacteristic *commandCharacteristic =
      service->createCharacteristic(dosey::ble::kCommandCharacteristicUuid,
                                    BLECharacteristic::PROPERTY_WRITE);
  commandCharacteristic->setCallbacks(&commandCallbacks);
  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(dosey::ble::kServiceUuid);
  advertising->setScanResponse(true);
  advertising->start();
  Serial.println("D1 EVT boot BLE_READY");
}

void loop() {
  processConnectionChanges();
  processInput();
  protocol.update(millis());
  sendNextOutputChunk();
}
