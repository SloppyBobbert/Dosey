import 'dart:io';

// Raster baselines follow the test runner host, not the simulated UI platform.
String robotFaceGoldenPath(String path, {String? operatingSystem}) {
  return switch (operatingSystem ?? Platform.operatingSystem) {
    'macos' => path,
    'linux' => path.replaceFirst('goldens/', 'goldens/linux/'),
    final host => throw UnsupportedError(
      'No Robot Face goldens for host: $host',
    ),
  };
}
