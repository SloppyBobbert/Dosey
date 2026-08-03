/// The sole approved foreground robot alarm sound.
enum ForegroundRobotAlarmSound {
  bellDing2(
    id: 'bell_ding2',
    label: 'Bell dings/chimes',
    creator: 'PWL',
    license: 'CC0',
    sourceUrl: 'https://opengameart.org/content/bell-dingschimes',
  );

  const ForegroundRobotAlarmSound({
    required this.id,
    required this.label,
    required this.creator,
    required this.license,
    required this.sourceUrl,
  });

  final String id;
  final String label;
  final String creator;
  final String license;
  final String sourceUrl;

  /// Converts a persisted sound ID to its approved sound contract.
  static ForegroundRobotAlarmSound parsePersistedId(String id) {
    for (final sound in values) {
      if (sound.id == id) {
        return sound;
      }
    }
    throw ArgumentError.value(
      id,
      'id',
      'Unknown foreground robot alarm sound ID.',
    );
  }
}

/// Immutable foreground robot alarm preferences.
///
/// Defaults are enabled, [ForegroundRobotAlarmSound.bellDing2], a 0.2 start
/// volume, gradual ramping enabled, and a 10-minute escalation duration.
final class ForegroundRobotAlarmSettings {
  ForegroundRobotAlarmSettings({
    this.enabled = true,
    this.sound = ForegroundRobotAlarmSound.bellDing2,
    this.startVolume = defaultStartVolume,
    this.gradualRampEnabled = true,
    this.escalationDuration = defaultEscalationDuration,
  }) {
    if (!startVolume.isFinite ||
        startVolume < minimumStartVolume ||
        startVolume > maximumStartVolume) {
      throw RangeError.value(
        startVolume,
        'startVolume',
        'Must be finite and between 0 and 1.',
      );
    }
    if (escalationDuration < minimumEscalationDuration ||
        escalationDuration > maximumEscalationDuration) {
      throw ArgumentError.value(
        escalationDuration,
        'escalationDuration',
        'Must be between 1 and 60 minutes.',
      );
    }
  }

  static const minimumStartVolume = 0.0;
  static const maximumStartVolume = 1.0;
  static const defaultStartVolume = 0.2;
  static const minimumEscalationDuration = Duration(minutes: 1);
  static const maximumEscalationDuration = Duration(minutes: 60);
  static const defaultEscalationDuration = Duration(minutes: 10);

  final bool enabled;
  final ForegroundRobotAlarmSound sound;
  final double startVolume;
  final bool gradualRampEnabled;
  final Duration escalationDuration;

  @override
  bool operator ==(Object other) =>
      other is ForegroundRobotAlarmSettings &&
      enabled == other.enabled &&
      sound == other.sound &&
      startVolume == other.startVolume &&
      gradualRampEnabled == other.gradualRampEnabled &&
      escalationDuration == other.escalationDuration;

  @override
  int get hashCode => Object.hash(
    enabled,
    sound,
    startVolume,
    gradualRampEnabled,
    escalationDuration,
  );
}

/// Inputs that establish whether a foreground alarm may be requested.
///
/// This is a necessary-condition policy only; it does not imply audible
/// playback or that an alarm system is ready.
final class ForegroundRobotAlarmInputs {
  const ForegroundRobotAlarmInputs({
    this.canonicalDoseReady = false,
    this.faceActive = false,
    this.appResumed = false,
  });

  final bool canonicalDoseReady;
  final bool faceActive;
  final bool appResumed;

  bool get shouldRequestForegroundAlarm =>
      canonicalDoseReady && faceActive && appResumed;

  @override
  bool operator ==(Object other) =>
      other is ForegroundRobotAlarmInputs &&
      canonicalDoseReady == other.canonicalDoseReady &&
      faceActive == other.faceActive &&
      appResumed == other.appResumed;

  @override
  int get hashCode => Object.hash(canonicalDoseReady, faceActive, appResumed);
}
