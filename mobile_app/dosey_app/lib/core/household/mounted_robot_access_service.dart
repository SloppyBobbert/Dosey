import 'dart:async';
import 'dart:developer' as developer;

import 'package:dosey_app/core/household/local_mounted_robot_access_repository.dart';
import 'package:dosey_app/core/household/mounted_robot_access_gateway.dart';

class MountedRobotAccessResult {
  const MountedRobotAccessResult({
    required this.robot,
    required this.isVerified,
  });

  final MountedRobotInstallation? robot;
  final bool isVerified;
}

enum MountedRobotAccessStatus {
  loading,
  verifiedMounted,
  verifiedUnmounted,
  offlineUnverifiedCache,
  error,
}

class MountedRobotAccessState {
  const MountedRobotAccessState({required this.status, this.robot, this.error});

  const MountedRobotAccessState.loading()
    : status = MountedRobotAccessStatus.loading,
      robot = null,
      error = null;

  final MountedRobotAccessStatus status;
  final MountedRobotInstallation? robot;
  final Object? error;
}

class MountedRobotAccessService {
  MountedRobotAccessService(this._gateway, this._cache);

  final MountedRobotAccessGateway _gateway;
  final LocalMountedRobotAccessRepository _cache;
  final StreamController<MountedRobotAccessResult> _changes =
      StreamController<MountedRobotAccessResult>.broadcast();
  final StreamController<MountedRobotAccessState> _states =
      StreamController<MountedRobotAccessState>.broadcast();
  MountedRobotAccessState _currentState =
      const MountedRobotAccessState.loading();
  Future<void>? _closeFuture;

  Stream<MountedRobotAccessResult> watch() => _changes.stream;
  Stream<MountedRobotAccessState> watchState() => Stream.multi((listener) {
    listener.add(_currentState);
    final subscription = _states.stream.listen(
      listener.add,
      onError: listener.addError,
    );
    listener.onCancel = subscription.cancel;
  });

  MountedRobotAccessState get currentState => _currentState;

  Future<void> close() {
    return _closeFuture ??= Future.wait([_changes.close(), _states.close()]);
  }

  Future<MountedRobotAccessResult> restoreForAccount(String accountId) async {
    _publishState(const MountedRobotAccessState.loading());
    try {
      final robot = await _gateway.restore();
      if (robot == null) {
        await _bestEffortCacheClear(accountId);
        const result = MountedRobotAccessResult(robot: null, isVerified: true);
        _publishState(
          const MountedRobotAccessState(
            status: MountedRobotAccessStatus.verifiedUnmounted,
          ),
        );
        _publishResult(result);
        return result;
      }
      final result = _verifiedMounted(robot);
      _publishResult(result);
      _publishState(
        MountedRobotAccessState(
          status: MountedRobotAccessStatus.verifiedMounted,
          robot: robot,
        ),
      );
      await _bestEffortCacheWrite(accountId, robot);
      return result;
    } on MountedRobotAccessTransportException {
      final cached = await _readCacheForOffline(accountId);
      final result = MountedRobotAccessResult(robot: cached, isVerified: false);
      _publishState(
        MountedRobotAccessState(
          status: MountedRobotAccessStatus.offlineUnverifiedCache,
          robot: cached,
        ),
      );
      _publishResult(result);
      return result;
    } on Object catch (error) {
      _publishState(
        MountedRobotAccessState(
          status: MountedRobotAccessStatus.error,
          error: error,
        ),
      );
      rethrow;
    }
  }

  Future<MountedRobotAccessResult> requireClaimedRobot(
    String accountId,
    String claimedRobotId,
  ) async {
    MountedRobotInstallation? robot;
    try {
      robot = await _gateway.restore();
    } on MountedRobotAccessTransportException {
      final cached = await _readCacheForOffline(accountId);
      _publishState(
        MountedRobotAccessState(
          status: MountedRobotAccessStatus.offlineUnverifiedCache,
          robot: cached,
        ),
      );
      rethrow;
    } on Object catch (error) {
      _publishState(
        MountedRobotAccessState(
          status: MountedRobotAccessStatus.error,
          error: error,
        ),
      );
      rethrow;
    }
    if (robot == null || robot.robotId != claimedRobotId) {
      const error = MountedRobotAccessException(
        'Mounted robot claim could not be verified.',
      );
      _publishState(
        const MountedRobotAccessState(
          status: MountedRobotAccessStatus.error,
          error: error,
        ),
      );
      throw error;
    }
    final result = _verifiedMounted(robot);
    _publishResult(result);
    _publishState(
      MountedRobotAccessState(
        status: MountedRobotAccessStatus.verifiedMounted,
        robot: robot,
      ),
    );
    await _bestEffortCacheWrite(accountId, robot);
    return result;
  }

  MountedRobotAccessResult _verifiedMounted(MountedRobotInstallation robot) =>
      MountedRobotAccessResult(robot: robot, isVerified: true);

  Future<void> _bestEffortCacheWrite(
    String accountId,
    MountedRobotInstallation robot,
  ) async {
    try {
      await _cache.replaceForAccount(
        accountId,
        robot,
        confirmedAt: DateTime.now().toUtc(),
      );
    } on Object catch (error, stackTrace) {
      developer.log(
        'Mounted robot cache write failed after verified authorization.',
        name: 'dosey.mounted_robot_access',
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _bestEffortCacheClear(String accountId) async {
    try {
      await _cache.clearForAccount(accountId);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Mounted robot cache clear failed after authoritative unmount.',
        name: 'dosey.mounted_robot_access',
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<MountedRobotInstallation?> _readCacheForOffline(
    String accountId,
  ) async {
    try {
      return (await _cache.readForAccount(accountId))?.robot;
    } on Object catch (error, stackTrace) {
      developer.log(
        'Mounted robot offline cache read failed.',
        name: 'dosey.mounted_robot_access',
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  void _publishResult(MountedRobotAccessResult result) {
    if (!_changes.isClosed) _changes.add(result);
  }

  void _publishState(MountedRobotAccessState state) {
    _currentState = state;
    if (!_states.isClosed) _states.add(state);
  }
}
