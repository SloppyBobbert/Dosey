import 'package:dosey_app/core/display/system_ui_gateway.dart';
import 'package:flutter/services.dart';

class FlutterSystemUiGateway implements SystemUiGateway {
  FlutterSystemUiGateway()
    : this.withOperations(
        enterOperation: _enterRobotFace,
        restoreOperation: _restoreAppUi,
      );

  FlutterSystemUiGateway.withOperations({
    required Future<void> Function() enterOperation,
    required Future<void> Function() restoreOperation,
  }) : this._operations(enterOperation, restoreOperation);

  FlutterSystemUiGateway._operations(
    this._enterOperation,
    this._restoreOperation,
  );

  final Future<void> Function() _enterOperation;
  final Future<void> Function() _restoreOperation;
  Future<void> _updates = Future<void>.value();
  bool _isRobotFaceDesired = false;
  bool _hasDesiredState = false;
  int _generation = 0;

  bool get isRobotFaceDesired => _isRobotFaceDesired;

  @override
  Future<void> enterRobotFace() => _setDesiredState(true);

  @override
  Future<void> restoreAppUi() => _setDesiredState(false);

  Future<void> _setDesiredState(bool robotFaceDesired) {
    if (_hasDesiredState && _isRobotFaceDesired == robotFaceDesired) {
      return _updates;
    }
    _hasDesiredState = true;
    _isRobotFaceDesired = robotFaceDesired;
    final generation = ++_generation;
    final operation = robotFaceDesired ? _enterOperation : _restoreOperation;
    _updates = _updates.then(
      (_) => _apply(generation, operation),
      onError: (_) => _apply(generation, operation),
    );
    return _updates;
  }

  Future<void> _apply(int generation, Future<void> Function() operation) async {
    try {
      await operation();
    } on Object {
      // Full-screen chrome is best effort; navigation must remain usable.
    }
    if (generation == _generation) return;
    // A newer desired state is already serialized immediately after this one.
  }

  static Future<void> _enterRobotFace() {
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  static Future<void> _restoreAppUi() {
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
