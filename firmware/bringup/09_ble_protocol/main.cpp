#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>

#include <atomic>
#include <cstring>

#include "arduino_protocol_hardware.h"
#include "ble_config.h"
#include "byte_queue.h"
#include "hardware_config.h"
#include "line_accumulator.h"
#include "protocol_engine.h"
#include "safety_limits.h"

namespace {

std::atomic<bool> deviceConnected{false};
std::atomic<bool> disconnectPending{false};
std::atomic<bool> inputOverflow{false};
dosey::ByteQueue inputBytes;
dosey::ByteQueue outputBytes;
BLEServer *bleServer = nullptr;
BLECharacteristic *eventCharacteristic = nullptr;

class BleProtocolOutput final : public dosey::ProtocolOutput {
public:
  bool writeLine(const char *line) override {
    if (!deviceConnected.load(std::memory_order_acquire) || line == nullptr) {
      return false;
    }

    const std::size_t length = std::strlen(line);
    if (length > dosey::kMaxProtocolLineLength) {
      return false;
    }
    std::uint8_t framed[dosey::kMaxProtocolLineLength + 1] = {};
    std::memcpy(framed, line, length);
    framed[length] = '\n';
    if (!outputBytes.push(framed, length + 1)) {
      Serial.println("BLE output queue full; command response rejected");
      return false;
    }
    return true;
  }
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
dosey::ArduinoProtocolHardware hardware;
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
    } else if (result == dosey::LineResult::lineInvalid) {
      protocol.handleLineInvalid();
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
  digitalWrite(dosey::hardware::kOnboardLedPin, dosey::inactiveLedLevel());
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
