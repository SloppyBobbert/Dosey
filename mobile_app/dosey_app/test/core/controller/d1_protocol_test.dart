import 'dart:convert';

import 'package:dosey_app/core/controller/d1_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes a bounded command with a newline', () {
    expect(
      utf8.decode(D1Protocol.encodeCommand('dose-1', D1Command.dispenseTest)),
      'D1 CMD dose-1 DISPENSE_TEST\n',
    );
  });

  test('encodes controller readiness and debug commands', () {
    expect(
      D1Command.values
          .where(
            (command) => {
              D1Command.deviceInfo,
              D1Command.configStatus,
              D1Command.safetyStatus,
              D1Command.debugOn,
              D1Command.debugOff,
            }.contains(command),
          )
          .map((command) => command.wireName),
      [
        'DEVICE_INFO',
        'CONFIG_STATUS',
        'SAFETY_STATUS',
        'DEBUG_ON',
        'DEBUG_OFF',
      ],
    );
  });

  test('rejects invalid command identifiers', () {
    expect(
      () => D1Protocol.encodeCommand('bad id', D1Command.status),
      throwsFormatException,
    );
  });

  test('parses exact event nack and error responses', () {
    expect(
      D1Protocol.parseResponse('D1 EVT dose-1 COMMAND_RECEIVED'),
      const D1Response(D1ResponseKind.event, 'dose-1', 'COMMAND_RECEIVED'),
    );
    expect(
      D1Protocol.parseResponse('D1 NACK dose-1 BUSY'),
      const D1Response(D1ResponseKind.nack, 'dose-1', 'BUSY'),
    );
    expect(
      D1Protocol.parseResponse('D1 ERROR dose-1 MOVEMENT_TIMEOUT'),
      const D1Response(D1ResponseKind.error, 'dose-1', 'MOVEMENT_TIMEOUT'),
    );
  });

  test('rejects malformed and unsupported responses', () {
    expect(
      () => D1Protocol.parseResponse('D2 EVT dose-1 COMMAND_RECEIVED'),
      throwsFormatException,
    );
    expect(
      () => D1Protocol.parseResponse('D1 EVT dose-1 COMMAND RECEIVED'),
      throwsFormatException,
    );
  });

  test('line decoder reassembles fragments and multiple lines', () {
    final decoder = D1LineDecoder();

    expect(decoder.add(ascii.encode('D1 EVT one STATUS_')), isEmpty);
    expect(decoder.add(ascii.encode('OK\nD1 EVT two HEARTBEAT_OK\n')), const [
      D1LineFrame('D1 EVT one STATUS_OK'),
      D1LineFrame('D1 EVT two HEARTBEAT_OK'),
    ]);
  });

  test('line decoder reports oversized input and recovers', () {
    final decoder = D1LineDecoder();

    expect(decoder.add([...List<int>.filled(97, 65), 10]), const [
      D1InvalidFrame(D1FrameError.lineTooLong),
    ]);
    expect(decoder.add(ascii.encode('D1 EVT ok STATUS_OK\n')), const [
      D1LineFrame('D1 EVT ok STATUS_OK'),
    ]);
  });

  test('line decoder rejects non-ASCII input and recovers at newline', () {
    final decoder = D1LineDecoder();

    expect(decoder.add([0x44, 0xff, 10]), const [
      D1InvalidFrame(D1FrameError.nonAscii),
    ]);
    expect(decoder.add(ascii.encode('D1 EVT ok STATUS_OK\n')), const [
      D1LineFrame('D1 EVT ok STATUS_OK'),
    ]);
  });

  test('splits writes into fixed 20-byte chunks', () {
    final bytes = List<int>.generate(43, (index) => index);

    expect(D1Protocol.chunk(bytes).map((part) => part.length), [20, 20, 3]);
  });
}
