import 'dart:io';

import 'package:dosey_app/core/alarm/foreground_robot_alarm_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ForegroundRobotAlarmInputs', () {
    for (final (
          canonicalDoseReady: canonicalDoseReady,
          faceActive: faceActive,
          appResumed: appResumed,
          shouldRequest: shouldRequest,
        )
        in const [
          (
            canonicalDoseReady: false,
            faceActive: false,
            appResumed: false,
            shouldRequest: false,
          ),
          (
            canonicalDoseReady: false,
            faceActive: false,
            appResumed: true,
            shouldRequest: false,
          ),
          (
            canonicalDoseReady: false,
            faceActive: true,
            appResumed: false,
            shouldRequest: false,
          ),
          (
            canonicalDoseReady: false,
            faceActive: true,
            appResumed: true,
            shouldRequest: false,
          ),
          (
            canonicalDoseReady: true,
            faceActive: false,
            appResumed: false,
            shouldRequest: false,
          ),
          (
            canonicalDoseReady: true,
            faceActive: false,
            appResumed: true,
            shouldRequest: false,
          ),
          (
            canonicalDoseReady: true,
            faceActive: true,
            appResumed: false,
            shouldRequest: false,
          ),
          (
            canonicalDoseReady: true,
            faceActive: true,
            appResumed: true,
            shouldRequest: true,
          ),
        ]) {
      test(
        'requests only when ready=$canonicalDoseReady, face=$faceActive, and resumed=$appResumed',
        () {
          expect(
            ForegroundRobotAlarmInputs(
              canonicalDoseReady: canonicalDoseReady,
              faceActive: faceActive,
              appResumed: appResumed,
            ).shouldRequestForegroundAlarm,
            shouldRequest,
          );
        },
      );
    }

    test('uses structural equality and hash codes', () {
      final inputs = ForegroundRobotAlarmInputs(
        canonicalDoseReady: true,
        faceActive: true,
        appResumed: true,
      );

      expect(
        inputs,
        equals(
          const ForegroundRobotAlarmInputs(
            canonicalDoseReady: true,
            faceActive: true,
            appResumed: true,
          ),
        ),
      );
      expect(
        inputs.hashCode,
        const ForegroundRobotAlarmInputs(
          canonicalDoseReady: true,
          faceActive: true,
          appResumed: true,
        ).hashCode,
      );
      expect(inputs, isNot(const ForegroundRobotAlarmInputs(appResumed: true)));
    });
  });

  group('ForegroundRobotAlarmSettings', () {
    test('preserves the approved defaults', () {
      final settings = ForegroundRobotAlarmSettings();

      expect(settings.enabled, isTrue);
      expect(settings.sound, ForegroundRobotAlarmSound.bellDing2);
      expect(settings.startVolume, 0.2);
      expect(settings.gradualRampEnabled, isTrue);
      expect(settings.escalationDuration, const Duration(minutes: 10));
    });

    test('accepts inclusive volume bounds', () {
      expect(
        () => ForegroundRobotAlarmSettings(startVolume: 0),
        returnsNormally,
      );
      expect(
        () => ForegroundRobotAlarmSettings(startVolume: 1),
        returnsNormally,
      );
    });

    test('rejects non-finite and out-of-range volumes', () {
      for (final volume in [
        -0.1,
        1.1,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => ForegroundRobotAlarmSettings(startVolume: volume),
          throwsA(isA<RangeError>()),
        );
      }
    });

    test('accepts inclusive escalation duration bounds', () {
      expect(
        () => ForegroundRobotAlarmSettings(
          escalationDuration: const Duration(minutes: 1),
        ),
        returnsNormally,
      );
      expect(
        () => ForegroundRobotAlarmSettings(
          escalationDuration: const Duration(minutes: 60),
        ),
        returnsNormally,
      );
    });

    test('rejects out-of-range escalation durations', () {
      for (final duration in const [Duration.zero, Duration(minutes: 61)]) {
        expect(
          () => ForegroundRobotAlarmSettings(escalationDuration: duration),
          throwsA(isA<ArgumentError>()),
        );
      }
    });

    test('uses structural equality and hash codes', () {
      final settings = ForegroundRobotAlarmSettings();

      expect(settings, equals(ForegroundRobotAlarmSettings()));
      expect(settings.hashCode, ForegroundRobotAlarmSettings().hashCode);
      expect(settings, isNot(ForegroundRobotAlarmSettings(enabled: false)));
    });
  });

  group('ForegroundRobotAlarmSound', () {
    test('round-trips every approved persisted sound ID', () {
      for (final sound in ForegroundRobotAlarmSound.values) {
        expect(ForegroundRobotAlarmSound.parsePersistedId(sound.id), sound);
      }
    });

    test('parses the approved persisted sound ID', () {
      final sound = ForegroundRobotAlarmSound.parsePersistedId('bell_ding2');

      expect(sound, ForegroundRobotAlarmSound.bellDing2);
      expect(sound.id, 'bell_ding2');
      expect(sound.label, 'Bell dings/chimes');
      expect(sound.creator, 'PWL');
      expect(sound.license, 'CC0');
      expect(
        sound.sourceUrl,
        'https://opengameart.org/content/bell-dingschimes',
      );
    });

    test('rejects unknown persisted sound IDs', () {
      expect(
        () => ForegroundRobotAlarmSound.parsePersistedId('unapproved_sound'),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('Unknown foreground robot alarm sound ID'),
          ),
        ),
      );
    });
  });

  test('contains no asynchronous, playback, or lifecycle implementation', () {
    final source = _policySource();

    for (final prohibited in const [
      'dart:async',
      'just_audio',
      'Future',
      'Stream',
      'Timer',
      'WidgetsBinding',
      'AppLifecycleState',
      'assetPath',
      '.wav',
    ]) {
      expect(source, isNot(contains(prohibited)), reason: prohibited);
    }
  });

  test('is not imported or constructed by other production libraries', () {
    final policyPath = File(
      'lib/core/alarm/foreground_robot_alarm_policy.dart',
    ).absolute.path;
    final productionFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => file.absolute.path != policyPath);

    for (final file in productionFiles) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('foreground_robot_alarm_policy.dart')));
      expect(source, isNot(contains('ForegroundRobotAlarmSettings(')));
      expect(source, isNot(contains('ForegroundRobotAlarmInputs(')));
    }
  });
}

String _policySource() => File(
  'lib/core/alarm/foreground_robot_alarm_policy.dart',
).readAsStringSync();
