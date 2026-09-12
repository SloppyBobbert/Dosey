import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'robot_face_golden_path.dart';

void main() {
  const path = 'goldens/robot_face_warm_companion_poses.png';

  test('Darwin keeps the original golden path', () {
    expect(robotFaceGoldenPath(path, operatingSystem: 'macos'), path);
  });

  test('Linux selects the separate baseline with the original filename', () {
    expect(
      robotFaceGoldenPath(path, operatingSystem: 'linux'),
      'goldens/linux/robot_face_warm_companion_poses.png',
    );
  });

  test('unsupported hosts fail explicitly', () {
    for (final host in ['windows', 'unknown', '']) {
      expect(
        () => robotFaceGoldenPath(path, operatingSystem: host),
        throwsUnsupportedError,
      );
    }
  });

  test('simulated target platforms never change the actual host selection', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final expected = robotFaceGoldenPath(
      path,
      operatingSystem: Platform.operatingSystem,
    );
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      expect(robotFaceGoldenPath(path), expected);
    }
  });

  for (final host in ['macos', 'linux']) {
    test(
      '$host compare and update share a path; failure output stays put',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'robot-face-golden-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final comparator = LocalFileComparator(
          directory.uri.resolve('example_test.dart'),
        );
        final golden = Uri.parse(
          robotFaceGoldenPath(path, operatingSystem: host),
        );
        final bytes = File('test/features/robot_face/$path').readAsBytesSync();

        // Only a disposable directory is written, never the repository baselines.
        await comparator.update(golden, bytes);
        expect(
          File.fromUri(
            directory.uri.resolve(golden.toString()),
          ).readAsBytesSync(),
          bytes,
        );
        expect(await comparator.compare(bytes, golden), isTrue);
        expect(
          comparator
              .getFailureFile('testImage', golden, comparator.basedir)
              .uri,
          directory.uri.resolve(
            'failures/robot_face_warm_companion_poses_testImage.png',
          ),
        );
      },
    );
  }
}
