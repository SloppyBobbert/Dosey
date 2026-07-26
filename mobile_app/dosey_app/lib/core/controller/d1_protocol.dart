import 'dart:convert';
import 'dart:math' as math;

enum D1Command {
  status('STATUS'),
  heartbeat('HEARTBEAT'),
  deviceInfo('DEVICE_INFO'),
  configStatus('CONFIG_STATUS'),
  safetyStatus('SAFETY_STATUS'),
  debugOn('DEBUG_ON'),
  debugOff('DEBUG_OFF'),
  ledTest('LED_TEST'),
  pirStatus('PIR_STATUS'),
  servoTest('SERVO_TEST'),
  dispenseTest('DISPENSE_TEST'),
  dispenseNext('DISPENSE_NEXT'),
  cancel('CANCEL');

  const D1Command(this.wireName);

  final String wireName;
}

enum D1ResponseKind { event, nack, error }

class D1Response {
  const D1Response(this.kind, this.id, this.code);

  final D1ResponseKind kind;
  final String id;
  final String code;

  @override
  bool operator ==(Object other) {
    return other is D1Response &&
        other.kind == kind &&
        other.id == id &&
        other.code == code;
  }

  @override
  int get hashCode => Object.hash(kind, id, code);
}

abstract class D1Frame {
  const D1Frame();
}

class D1LineFrame extends D1Frame {
  const D1LineFrame(this.line);

  final String line;

  @override
  bool operator ==(Object other) => other is D1LineFrame && other.line == line;

  @override
  int get hashCode => line.hashCode;
}

enum D1FrameError { lineTooLong, nonAscii }

class D1InvalidFrame extends D1Frame {
  const D1InvalidFrame(this.error);

  final D1FrameError error;

  @override
  bool operator ==(Object other) {
    return other is D1InvalidFrame && other.error == error;
  }

  @override
  int get hashCode => error.hashCode;
}

class D1Protocol {
  static const serviceUuid = '8f3a1001-6f5b-4d4f-9c2a-5d6e7f801001';
  static const commandCharacteristicUuid =
      '8f3a1002-6f5b-4d4f-9c2a-5d6e7f801001';
  static const eventCharacteristicUuid = '8f3a1003-6f5b-4d4f-9c2a-5d6e7f801001';
  static const deviceName = 'Dosey-XIAO-C6';
  static const maxLineLength = 96;
  static const maxCommandIdLength = 24;
  static const chunkSize = 20;

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,24}$');
  static final RegExp _codePattern = RegExp(r'^[A-Z0-9_]+$');

  static List<int> encodeCommand(String id, D1Command command) {
    if (!_idPattern.hasMatch(id)) {
      throw const FormatException('Invalid D1 command identifier.');
    }
    final line = 'D1 CMD $id ${command.wireName}\n';
    if (line.length - 1 > maxLineLength) {
      throw const FormatException('D1 command exceeds the line limit.');
    }
    return ascii.encode(line);
  }

  static D1Response parseResponse(String input) {
    final line = input.endsWith('\r')
        ? input.substring(0, input.length - 1)
        : input;
    final fields = line.split(' ');
    if (fields.length != 4 ||
        fields[0] != 'D1' ||
        !_idPattern.hasMatch(fields[2]) ||
        !_codePattern.hasMatch(fields[3])) {
      throw const FormatException('Malformed D1 response.');
    }
    final kind = switch (fields[1]) {
      'EVT' => D1ResponseKind.event,
      'NACK' => D1ResponseKind.nack,
      'ERROR' => D1ResponseKind.error,
      _ => throw const FormatException('Unsupported D1 response kind.'),
    };
    return D1Response(kind, fields[2], fields[3]);
  }

  static List<List<int>> chunk(List<int> bytes) {
    return [
      for (var offset = 0; offset < bytes.length; offset += chunkSize)
        bytes.sublist(offset, math.min(offset + chunkSize, bytes.length)),
    ];
  }
}

class D1LineDecoder {
  final List<int> _bytes = [];
  D1FrameError? _error;

  List<D1Frame> add(List<int> bytes) {
    final frames = <D1Frame>[];
    for (final byte in bytes) {
      if (byte == 10) {
        final error = _error;
        if (error == null) {
          frames.add(D1LineFrame(ascii.decode(_bytes)));
        } else {
          frames.add(D1InvalidFrame(error));
        }
        _bytes.clear();
        _error = null;
        continue;
      }
      if (_error != null) {
        continue;
      }
      if (byte > 0x7f || byte < 0) {
        _bytes.clear();
        _error = D1FrameError.nonAscii;
      } else if (_bytes.length >= D1Protocol.maxLineLength) {
        _bytes.clear();
        _error = D1FrameError.lineTooLong;
      } else {
        _bytes.add(byte);
      }
    }
    return frames;
  }

  void reset() {
    _bytes.clear();
    _error = null;
  }
}
