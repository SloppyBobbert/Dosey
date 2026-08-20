import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/appwrite_profile.dart' as profiles;

Map<String, dynamic> onlineProfile() => {
  'environment': 'isolated',
  'status': 'available',
  'APPWRITE_ENDPOINT': 'https://example.invalid/v1',
  'APPWRITE_PROJECT_ID': 'isolated-project',
  'APPWRITE_CREATE_PAIRING_CODE_FUNCTION_ID': 'create-code',
  'APPWRITE_CLAIM_ROBOT_FUNCTION_ID': 'claim-robot',
  'APPWRITE_CREATE_ROBOT_FUNCTION_ID': 'create-robot',
  'APPWRITE_CREATE_HOUSEHOLD_INVITATION_FUNCTION_ID': 'invite-member',
  'APPWRITE_ACCEPT_HOUSEHOLD_INVITATION_FUNCTION_ID': 'accept-member',
  'APPWRITE_REMOVE_HOUSEHOLD_MEMBER_FUNCTION_ID': 'remove-member',
  'CAREGIVER_SYNC_ENABLED': false,
};

void main() {
  final root = Directory.current.path;
  final profileDir = '$root/config/appwrite';

  test('accepts a valid isolated public profile', () {
    expect(
      profiles.validateProfile(onlineProfile()),
      'appwrite-callback-isolated-project',
    );
  });

  test('accepts the explicit offline profile deterministically', () {
    final profile =
        jsonDecode(File('$profileDir/offline.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(profiles.validateProfile(profile), 'appwrite-callback-offline');
  });

  test('rejects unavailable named shells', () {
    for (final name in ['development', 'staging', 'production']) {
      final profile =
          jsonDecode(File('$profileDir/$name.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(() => profiles.validateProfile(profile), throwsFormatException);
    }
  });

  test('rejects malformed, unknown, forbidden, and partial profile values', () {
    final malformed = onlineProfile()
      ..['APPWRITE_ENDPOINT'] = 'http://example.invalid';
    final unknown = onlineProfile()..['APPWRITE_API_KEY'] = 'not-allowed';
    final partialPairing = onlineProfile()
      ..remove('APPWRITE_CLAIM_ROBOT_FUNCTION_ID');
    final partialMedication = onlineProfile()
      ..['CAREGIVER_SYNC_ENABLED'] = true
      ..['APPWRITE_MEDICATION_SYNC_PUSH_FUNCTION_ID'] = 'push';
    for (final profile in [
      malformed,
      unknown,
      partialPairing,
      partialMedication,
    ]) {
      expect(() => profiles.validateProfile(profile), throwsFormatException);
    }
  });

  test('rejects enabled medication sync without its complete group', () {
    final profile = onlineProfile()..['CAREGIVER_SYNC_ENABLED'] = true;
    expect(() => profiles.validateProfile(profile), throwsFormatException);
  });

  test('keeps staging and production medication sync disabled', () {
    for (final environment in ['staging', 'production']) {
      final profile = onlineProfile()
        ..['environment'] = environment
        ..['CAREGIVER_SYNC_ENABLED'] = true
        ..['APPWRITE_MEDICATION_SYNC_PUSH_FUNCTION_ID'] = 'push'
        ..['APPWRITE_MEDICATION_SYNC_PULL_FUNCTION_ID'] = 'pull';
      expect(() => profiles.validateProfile(profile), throwsFormatException);
    }
  });

  test('adds the native flavor for Android builds only', () {
    expect(
      profiles.flutterArguments(
        flavor: 'personal',
        profilePath: 'config/appwrite/offline.json',
        forwarded: ['build', 'apk', '--debug'],
      ),
      containsAllInOrder(['build', 'apk', '--debug', '--flavor', 'personal']),
    );
    expect(
      profiles.flutterArguments(
        flavor: 'personal',
        profilePath: 'config/appwrite/offline.json',
        forwarded: ['build', 'ios', '--debug'],
      ),
      isNot(contains('--flavor')),
    );
  });

  test('rejects Robot iOS builds', () {
    expect(
      () => profiles.flutterArguments(
        flavor: 'robot',
        profilePath: 'config/appwrite/offline.json',
        forwarded: ['build', 'ios', '--debug'],
      ),
      throwsFormatException,
    );
  });

  test('omits native flavor for Personal IPA builds', () {
    expect(
      profiles.flutterArguments(
        flavor: 'personal',
        profilePath: 'config/appwrite/offline.json',
        forwarded: ['build', 'ipa'],
      ),
      isNot(contains('--flavor')),
    );
  });

  test('rejects Robot IPA builds', () {
    expect(
      () => profiles.flutterArguments(
        flavor: 'robot',
        profilePath: 'config/appwrite/offline.json',
        forwarded: ['build', 'ipa'],
      ),
      throwsFormatException,
    );
  });

  test('requires generated metadata for Android --no-pub builds', () {
    const requiredMetadata = {
      '.dart_tool/package_config.json',
      '.dart_tool/package_graph.json',
      '.flutter-plugins-dependencies',
    };
    for (final forwarded in [
      ['build', 'apk', '--debug', '--no-pub'],
      ['build', 'appbundle', '--release', '--no-pub'],
    ]) {
      for (final missing in requiredMetadata) {
        final existingMetadata = {...requiredMetadata}..remove(missing);

        expect(
          () => profiles.validateNoPubAndroidBuildMetadata(
            forwarded,
            existingMetadata: existingMetadata,
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'Android --no-pub builds require generated Flutter package metadata. Run flutter pub get first.',
            ),
          ),
          reason: '$forwarded without $missing',
        );
      }
    }
  });

  test('accepts Android --no-pub builds with generated metadata', () {
    for (final forwarded in [
      ['build', 'appbundle', '--release', '--no-pub'],
      ['--verbose', 'build', 'apk', '--no-pub'],
      ['-v', 'build', 'appbundle', '--no-pub'],
      ['-d', 'emulator-5554', 'build', 'apk', '--no-pub'],
      ['--device-id', 'emulator-5554', 'build', 'appbundle', '--no-pub'],
      ['--device-id=emulator-5554', 'build', 'apk', '--no-pub'],
    ]) {
      profiles.validateNoPubAndroidBuildMetadata(
        forwarded,
        existingMetadata: const {
          '.dart_tool/package_config.json',
          '.dart_tool/package_graph.json',
          '.flutter-plugins-dependencies',
        },
      );
    }
  });

  test('guards Android --no-pub builds after Flutter options', () {
    for (final forwarded in [
      ['--verbose', 'build', 'apk', '--no-pub'],
      ['-v', 'build', 'appbundle', '--no-pub'],
      ['-d', 'emulator-5554', 'build', 'apk', '--no-pub'],
      ['--device-id', 'emulator-5554', 'build', 'appbundle', '--no-pub'],
      ['--device-id=emulator-5554', 'build', 'apk', '--no-pub'],
    ]) {
      expect(
        () => profiles.validateNoPubAndroidBuildMetadata(
          forwarded,
          existingMetadata: const {},
        ),
        throwsFormatException,
      );
    }
  });

  test('does not guard commands outside Android --no-pub builds', () {
    for (final forwarded in [
      ['test', '--no-pub'],
      ['build', 'apk', '--debug'],
      ['build', 'web', '--no-pub'],
      ['build', 'ios', '--no-pub'],
      ['run', 'build', 'apk', '--no-pub'],
      ['run', 'build', 'appbundle', '--no-pub'],
    ]) {
      profiles.validateNoPubAndroidBuildMetadata(
        forwarded,
        existingMetadata: const {},
      );
    }
  });

  test('accepts mounted lookup independently and endpoint project alone', () {
    final profile = onlineProfile()
      ..remove('APPWRITE_CREATE_PAIRING_CODE_FUNCTION_ID')
      ..remove('APPWRITE_CLAIM_ROBOT_FUNCTION_ID')
      ..remove('APPWRITE_CREATE_ROBOT_FUNCTION_ID')
      ..remove('APPWRITE_CREATE_HOUSEHOLD_INVITATION_FUNCTION_ID')
      ..remove('APPWRITE_ACCEPT_HOUSEHOLD_INVITATION_FUNCTION_ID')
      ..remove('APPWRITE_REMOVE_HOUSEHOLD_MEMBER_FUNCTION_ID')
      ..['APPWRITE_GET_MOUNTED_ROBOT_FUNCTION_ID'] = 'mounted_lookup';
    expect(
      profiles.validateProfile(profile),
      'appwrite-callback-isolated-project',
    );
  });

  test('rejects unsafe public URL and project values', () {
    for (final mutation in [
      {'APPWRITE_ENDPOINT': 'https://user@example.invalid/v1'},
      {'APPWRITE_ENDPOINT': 'https://example.invalid:443/v1'},
      {'APPWRITE_PROJECT_ID': 'unsafe_project'},
      {'APPWRITE_PROJECT_ID': ' isolated-project'},
    ]) {
      expect(
        () => profiles.validateProfile(onlineProfile()..addAll(mutation)),
        throwsFormatException,
      );
    }
  });

  test('accepts 36-character Function IDs and rejects 37-character IDs', () {
    final accepted = onlineProfile()
      ..['APPWRITE_GET_MOUNTED_ROBOT_FUNCTION_ID'] = 'a' * 36;
    final rejected = onlineProfile()
      ..['APPWRITE_GET_MOUNTED_ROBOT_FUNCTION_ID'] = 'a' * 37;
    expect(profiles.validateProfile(accepted), isNotEmpty);
    expect(() => profiles.validateProfile(rejected), throwsFormatException);
  });

  test('rejects independently malformed endpoints', () {
    for (final endpoint in [
      'http://example.invalid/v1',
      'https://example.invalid',
      'https://user@example.invalid/v1',
      'https://example.invalid:8443/v1',
      'https://example.invalid/v1?query=value',
      'https://example.invalid/v1#fragment',
    ]) {
      expect(
        () => profiles.validateProfile(
          onlineProfile()..['APPWRITE_ENDPOINT'] = endpoint,
        ),
        throwsFormatException,
      );
    }
  });

  test('parses only documented wrapper arguments', () {
    expect(
      profiles.parseWrapperArguments([
        'prepare',
        '--profile',
        'offline.json',
        '--flavor',
        'personal',
      ]).flavor,
      'personal',
    );
    for (final arguments in [
      ['validate', '--profile', 'a', '--profile', 'b'],
      ['prepare', '--flavor', 'personal', '--profile', 'a'],
      ['prepare', '--profile', 'a', '--flavor', 'robot'],
      ['flutter', '--profile', 'a', '--flavor', 'personal', '--'],
      [
        'flutter',
        '--profile',
        'a',
        '--flavor',
        'personal',
        '--',
        'build',
        'apk',
        '--flavor=robot',
      ],
    ]) {
      expect(
        () => profiles.parseWrapperArguments(arguments),
        throwsFormatException,
      );
    }
  });
}
