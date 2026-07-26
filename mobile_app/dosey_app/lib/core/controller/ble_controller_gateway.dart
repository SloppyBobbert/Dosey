import 'dart:async';

// Named public constructor parameters intentionally initialize private fields.
// ignore_for_file: prefer_initializing_formals

import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/d1_protocol.dart';

typedef RobotModeAccess = FutureOr<bool> Function();
typedef PrepareBleAccess = Future<bool> Function();

class BleControllerGateway
    implements
        StagedControllerGateway,
        ControllerBenchGateway,
        ControllerEventGateway {
  BleControllerGateway({
    required DoseyBleGateway transport,
    required RobotModeAccess canHostRobot,
    PrepareBleAccess? prepareBleAccess,
    Duration commandTimeout = const Duration(seconds: 8),
  }) : _transport = transport,
       _canHostRobot = canHostRobot,
       _prepareBleAccess = prepareBleAccess ?? _allowBleAccess,
       _commandTimeout = commandTimeout {
    _connectionSubscription = _transport.watchConnection().listen(
      _handleConnection,
      onError: (_) => _handleTransportFailure(),
    );
    _protocolSubscription = _transport.watchProtocolBytes().listen(
      _handleBytes,
      onError: (_) => _handleTransportFailure(),
    );
  }

  final DoseyBleGateway _transport;
  final RobotModeAccess _canHostRobot;
  final PrepareBleAccess _prepareBleAccess;
  final Duration _commandTimeout;
  final D1LineDecoder _decoder = D1LineDecoder();
  final _controller = StreamController<ControllerSnapshot>.broadcast();
  final _controllerEvents = StreamController<ControllerEvent>.broadcast();

  late final StreamSubscription<BleConnectionSnapshot> _connectionSubscription;
  late final StreamSubscription<List<int>> _protocolSubscription;
  ControllerSnapshot _snapshot = const ControllerSnapshot.disconnected();
  _PendingCommand? _pending;
  Future<void> _responseChain = Future<void>.value();
  int _nextId = 1;
  bool _closed = false;

  @override
  Stream<ControllerSnapshot> watchController() async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Stream<ControllerEvent> watchControllerEvents() => _controllerEvents.stream;

  @override
  Future<void> connect() async {
    if (_snapshot.connectionState == ControllerConnectionState.connected) {
      return;
    }
    if (!await _prepareBleAccess()) {
      throw const ControllerCommandPreconditionException(
        'Bluetooth scan and connection permissions are required.',
      );
    }
    _setSnapshot(
      const ControllerSnapshot(
        connectionState: ControllerConnectionState.scanning,
        canRequestDispense: false,
        statusLabel: 'Scanning for Dosey controller',
      ),
    );
    try {
      await _transport.connectToDosey();
      _setSnapshot(const ControllerSnapshot.connected());
    } on Object {
      _setSnapshot(
        const ControllerSnapshot(
          connectionState: ControllerConnectionState.error,
          canRequestDispense: false,
          statusLabel: 'Controller connection failed',
        ),
      );
      rethrow;
    }
  }

  @override
  Future<void> disconnect() => _transport.disconnect();

  @override
  Future<void> requestDispense({required String doseId}) {
    return requestStagedDispense(
      doseId: doseId,
      movement: ControllerMovementCommand.dispenseNext,
      onStage: (_) async {},
    );
  }

  @override
  Future<void> requestStagedDispense({
    required String doseId,
    ControllerMovementCommand movement = ControllerMovementCommand.dispenseNext,
    required ControllerDispenseStageCallback onStage,
  }) async {
    _requireConnected();
    final access = _canHostRobot();
    final canHostRobot = access is Future<bool> ? await access : access;
    if (!canHostRobot) {
      throw const ControllerCommandPreconditionException(
        'Robot Mode must be active before movement.',
      );
    }
    final command = switch (movement) {
      ControllerMovementCommand.servoTest => D1Command.servoTest,
      ControllerMovementCommand.dispenseTest => D1Command.dispenseTest,
      ControllerMovementCommand.dispenseNext => D1Command.dispenseNext,
    };
    await _send(command, onStage: onStage);
  }

  @override
  Future<String> runBenchCommand(ControllerBenchCommand command) {
    final protocolCommand = switch (command) {
      ControllerBenchCommand.status => D1Command.status,
      ControllerBenchCommand.heartbeat => D1Command.heartbeat,
      ControllerBenchCommand.deviceInfo => D1Command.deviceInfo,
      ControllerBenchCommand.configStatus => D1Command.configStatus,
      ControllerBenchCommand.safetyStatus => D1Command.safetyStatus,
      ControllerBenchCommand.debugOn => D1Command.debugOn,
      ControllerBenchCommand.debugOff => D1Command.debugOff,
      ControllerBenchCommand.pirStatus => D1Command.pirStatus,
      ControllerBenchCommand.ledTest => D1Command.ledTest,
      ControllerBenchCommand.servoTest ||
      ControllerBenchCommand.dispenseTest => throw ArgumentError(
        'Movement bench commands must use the dispense lifecycle.',
      ),
    };
    return _send(protocolCommand);
  }

  @override
  Future<void> cancelActiveCommand() async {
    final active = _pending;
    if (active == null || !active.isMovement) return;
    final id = _newId();
    try {
      await _transport.writeProtocolBytes(
        D1Protocol.encodeCommand(id, D1Command.cancel),
      );
    } on Object {
      _failPending(const ControllerCommandInterruptedException());
      rethrow;
    }
  }

  Future<String> _send(
    D1Command command, {
    ControllerDispenseStageCallback? onStage,
  }) async {
    _requireConnected();
    if (_pending != null) {
      throw const ControllerCommandPreconditionException(
        'Another controller command is already active.',
      );
    }
    final id = _newId();
    final pending = _PendingCommand(id: id, command: command, onStage: onStage);
    _pending = pending;
    pending.timer = Timer(_commandTimeout, () {
      if (_pending != pending) return;
      _failPending(
        pending.accepted
            ? const ControllerCommandTimeoutException()
            : const ControllerCommandPreAcceptanceTimeoutException(),
      );
    });
    try {
      await _transport.writeProtocolBytes(
        D1Protocol.encodeCommand(id, command),
      );
    } on Object {
      _failPending(const ControllerTransportOfflineException());
    }
    return pending.completer.future;
  }

  void _handleBytes(List<int> bytes) {
    for (final frame in _decoder.add(bytes)) {
      _responseChain = _responseChain.then((_) => _handleFrame(frame)).onError((
        error,
        stackTrace,
      ) {
        _failPending(
          error ?? StateError('Unknown controller response failure.'),
          stackTrace,
        );
      });
    }
  }

  Future<void> _handleFrame(D1Frame frame) async {
    if (frame is D1InvalidFrame) {
      if (_pending != null) {
        _failPending(
          const ControllerCommandInterruptedException(
            'Controller sent an invalid protocol frame.',
          ),
        );
      }
      return;
    }
    final line = (frame as D1LineFrame).line;
    D1Response response;
    try {
      response = D1Protocol.parseResponse(line);
    } on FormatException {
      if (_pending != null) {
        _failPending(
          const ControllerCommandInterruptedException(
            'Controller sent a malformed protocol response.',
          ),
        );
      }
      return;
    }
    if (response ==
        const D1Response(D1ResponseKind.event, 'pir', 'WAKE_FACE')) {
      if (!_closed) _controllerEvents.add(ControllerEvent.wakeFace);
      return;
    }
    final pending = _pending;
    if (pending == null) return;
    if (response.id != pending.id) return;

    if (response.kind == D1ResponseKind.nack) {
      _failPending(ControllerCommandRejectedException(response.code));
      return;
    }
    if (response.kind == D1ResponseKind.error) {
      if (response.code == 'MOVEMENT_TIMEOUT') {
        _failPending(const ControllerCommandTimeoutException());
      } else if (response.code == 'SERVO_ATTACH_FAILED') {
        _failPending(
          const ControllerCommandRejectedException(
            'Servo could not attach; movement did not start.',
          ),
        );
      } else {
        _failPending(
          pending.accepted
              ? ControllerCommandInterruptedException(response.code)
              : ControllerCommandRejectedException(response.code),
        );
      }
      return;
    }

    switch (response.code) {
      case 'COMMAND_RECEIVED':
        if (!pending.accepted) {
          pending.accepted = true;
          if (pending.isMovement) {
            await pending.onStage!(ControllerDispenseStage.accepted);
          }
        }
      case 'MOVEMENT_STARTED':
        if (pending.isMovement) {
          if (!pending.accepted) {
            pending.accepted = true;
            await pending.onStage!(ControllerDispenseStage.accepted);
          }
          if (!pending.movementStarted) {
            pending.movementStarted = true;
            await pending.onStage!(ControllerDispenseStage.movementStarted);
          }
        } else {
          pending.details.add(response.code);
        }
      case 'SERVO_DONE':
        _completePending();
      case 'MOVEMENT_CANCELLED_UNRESOLVED':
        _failPending(
          const ControllerCommandInterruptedException(
            'Controller movement was cancelled and remains unresolved.',
          ),
        );
      default:
        pending.details.add(response.code);
        if (_isDiagnosticTerminal(pending.command, response.code)) {
          _completePending();
        }
    }
  }

  bool _isDiagnosticTerminal(D1Command command, String code) {
    return switch (command) {
      D1Command.status => code == 'MOVEMENT_ACTIVE' || code == 'MOVEMENT_IDLE',
      D1Command.heartbeat => code == 'HEARTBEAT_OK',
      D1Command.deviceInfo => code == 'BUILD_BASELINE' || code == 'BUILD_DEBUG',
      D1Command.configStatus => code == 'GROVE_BASE_D8_SERVO_PROFILE',
      D1Command.safetyStatus => code == 'DISPENSE_NEXT_DISABLED',
      D1Command.debugOn => code == 'DEBUG_ON',
      D1Command.debugOff => code == 'DEBUG_OFF',
      D1Command.ledTest => code == 'LED_TEST_DONE',
      D1Command.pirStatus => code == 'PIR_MOTION' || code == 'PIR_CLEAR',
      D1Command.servoTest ||
      D1Command.dispenseTest ||
      D1Command.dispenseNext ||
      D1Command.cancel => false,
    };
  }

  void _handleConnection(BleConnectionSnapshot snapshot) {
    switch (snapshot.state) {
      case BleConnectionState.connecting:
        _setSnapshot(
          const ControllerSnapshot(
            connectionState: ControllerConnectionState.scanning,
            canRequestDispense: false,
            statusLabel: 'Connecting to Dosey controller',
          ),
        );
      case BleConnectionState.connected:
        _setSnapshot(const ControllerSnapshot.connected());
      case BleConnectionState.disconnecting:
      case BleConnectionState.disconnected:
        _decoder.reset();
        _handleTransportFailure();
        _setSnapshot(const ControllerSnapshot.disconnected());
    }
  }

  void _handleTransportFailure() {
    final pending = _pending;
    if (pending == null) return;
    _failPending(
      pending.accepted
          ? const ControllerCommandInterruptedException()
          : const ControllerTransportOfflineException(),
    );
  }

  void _completePending() {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    pending.timer?.cancel();
    pending.completer.complete(pending.details.join(', '));
  }

  void _failPending(Object error, [StackTrace? stackTrace]) {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    pending.timer?.cancel();
    pending.completer.completeError(error, stackTrace);
  }

  void _requireConnected() {
    if (_snapshot.connectionState != ControllerConnectionState.connected) {
      throw const ControllerTransportOfflineException();
    }
  }

  String _newId() => 'app-${_nextId++}';

  static Future<bool> _allowBleAccess() async => true;

  void _setSnapshot(ControllerSnapshot snapshot) {
    if (_closed) return;
    _snapshot = snapshot;
    _controller.add(snapshot);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _failPending(const ControllerTransportOfflineException());
    await _connectionSubscription.cancel();
    await _protocolSubscription.cancel();
    await _controller.close();
    await _controllerEvents.close();
  }
}

class _PendingCommand {
  _PendingCommand({
    required this.id,
    required this.command,
    required this.onStage,
  });

  final String id;
  final D1Command command;
  final ControllerDispenseStageCallback? onStage;
  final Completer<String> completer = Completer<String>();
  final List<String> details = [];
  Timer? timer;
  bool accepted = false;
  bool movementStarted = false;

  bool get isMovement => onStage != null;
}
