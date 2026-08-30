import 'dart:convert';
import 'dart:io';

const _cloudKeys = {
  'APPWRITE_ENDPOINT',
  'APPWRITE_PROJECT_ID',
  'APPWRITE_CREATE_PAIRING_CODE_FUNCTION_ID',
  'APPWRITE_CLAIM_ROBOT_FUNCTION_ID',
  'APPWRITE_CREATE_ROBOT_FUNCTION_ID',
  'APPWRITE_CREATE_HOUSEHOLD_INVITATION_FUNCTION_ID',
  'APPWRITE_ACCEPT_HOUSEHOLD_INVITATION_FUNCTION_ID',
  'APPWRITE_REMOVE_HOUSEHOLD_MEMBER_FUNCTION_ID',
  'APPWRITE_MEDICATION_SYNC_PUSH_FUNCTION_ID',
  'APPWRITE_MEDICATION_SYNC_PULL_FUNCTION_ID',
  'APPWRITE_GET_MOUNTED_ROBOT_FUNCTION_ID',
};
const _allowedKeys = {
  ..._cloudKeys,
  'APPWRITE_CALLBACK_SCHEME',
  'WEB_APP_ORIGIN',
  'CAREGIVER_SYNC_ENABLED',
  'environment',
  'status',
};
const _pairingKeys = {
  'APPWRITE_CREATE_PAIRING_CODE_FUNCTION_ID',
  'APPWRITE_CLAIM_ROBOT_FUNCTION_ID',
};
const _householdKeys = {
  'APPWRITE_CREATE_ROBOT_FUNCTION_ID',
  'APPWRITE_CREATE_HOUSEHOLD_INVITATION_FUNCTION_ID',
  'APPWRITE_ACCEPT_HOUSEHOLD_INVITATION_FUNCTION_ID',
  'APPWRITE_REMOVE_HOUSEHOLD_MEMBER_FUNCTION_ID',
};
const _medicationKeys = {
  'APPWRITE_MEDICATION_SYNC_PUSH_FUNCTION_ID',
  'APPWRITE_MEDICATION_SYNC_PULL_FUNCTION_ID',
};
final _functionId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,35}$');
final _projectId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9.-]{0,63}$');
const _requiredNoPubAndroidBuildMetadata = {
  '.dart_tool/package_config.json',
  '.dart_tool/package_graph.json',
  '.flutter-plugins-dependencies',
};

void main(List<String> arguments) async {
  try {
    if (arguments.isEmpty) {
      throw const FormatException('A command is required.');
    }
    parseWrapperArguments(arguments);
    switch (arguments.first) {
      case 'validate':
        final profile = loadProfile(_requiredOption(arguments, '--profile'));
        validateProfile(profile);
      case 'flutter':
        await _runFlutter(arguments.skip(1).toList());
      default:
        throw const FormatException('Unknown command.');
    }
  } on FormatException catch (error) {
    stderr.writeln('Invalid Appwrite profile: ${error.message}');
    exitCode = 64;
  } on FileSystemException {
    stderr.writeln('Invalid Appwrite profile: file access failed.');
    exitCode = 64;
  }
}

class WrapperArguments {
  const WrapperArguments(this.flavor);
  final String? flavor;
}

WrapperArguments parseWrapperArguments(List<String> arguments) {
  if (arguments.isEmpty) throw const FormatException('A command is required.');
  final command = arguments.first;
  final separator = arguments.indexOf('--');
  final options = separator < 0
      ? arguments.sublist(1)
      : arguments.sublist(1, separator);
  final forwarded = separator < 0
      ? <String>[]
      : arguments.sublist(separator + 1);
  final expectsFlavor = command == 'flutter';
  final expected = expectsFlavor ? ['--profile', '--flavor'] : ['--profile'];
  if (!{'validate', 'flutter'}.contains(command) ||
      options.length != expected.length * 2 ||
      !List.generate(
        expected.length,
        (i) => options[i * 2] == expected[i],
      ).every((ok) => ok) ||
      options[1].isEmpty) {
    throw const FormatException('Wrapper options are invalid.');
  }
  final flavor = expectsFlavor ? options[3] : null;
  if (expectsFlavor && !{'personal', 'robot'}.contains(flavor)) {
    throw const FormatException('Wrapper flavor is invalid.');
  }
  if (command == 'flutter' &&
      (separator < 0 ||
          forwarded.isEmpty ||
          forwarded.any(
            (arg) =>
                arg == '--flavor' ||
                arg.startsWith('--flavor=') ||
                arg.startsWith('--dart-define') ||
                arg.contains('DOSEY_BUILD_PROFILE') ||
                arg.contains('DOSEY_RUNTIME_CAPABILITY'),
          ))) {
    throw const FormatException(
      'Flutter arguments override profile configuration.',
    );
  }
  if (command != 'flutter' && separator >= 0) {
    throw const FormatException('Wrapper options are invalid.');
  }
  if (command == 'flutter') _rejectNativeIosBuild(forwarded);
  return WrapperArguments(flavor);
}

Map<String, dynamic> loadProfile(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Profile must be a JSON object.');
  }
  return decoded;
}

String validateProfile(Map<String, dynamic> profile) {
  if (profile.keys.any((key) => !_allowedKeys.contains(key))) {
    throw const FormatException('Profile contains an unsupported key.');
  }
  final environment = _text(profile, 'environment');
  final status = _text(profile, 'status');
  if (environment == null || status == null) {
    throw const FormatException('Profile metadata is incomplete.');
  }
  if (status == 'unavailable') {
    throw const FormatException('This named profile is unavailable.');
  }
  if (status != 'available') {
    throw const FormatException('Profile status is invalid.');
  }
  final enabled =
      _text(profile, 'APPWRITE_ENDPOINT') != null ||
      _text(profile, 'APPWRITE_PROJECT_ID') != null;
  if (enabled) {
    final endpoint = _text(profile, 'APPWRITE_ENDPOINT');
    final project = _text(profile, 'APPWRITE_PROJECT_ID');
    if (endpoint == null ||
        project == null ||
        !_validEndpoint(endpoint) ||
        !_projectId.hasMatch(project)) {
      throw const FormatException(
        'Appwrite endpoint or project ID is invalid.',
      );
    }
  }
  for (final key in _cloudKeys.difference({
    'APPWRITE_ENDPOINT',
    'APPWRITE_PROJECT_ID',
  })) {
    final value = _text(profile, key);
    if (value != null && !_functionId.hasMatch(value)) {
      throw const FormatException('A Function ID is invalid.');
    }
  }
  _requireComplete(profile, _pairingKeys);
  _requireComplete(profile, _householdKeys);
  _requireComplete(profile, _medicationKeys);
  final sync = profile['CAREGIVER_SYNC_ENABLED'];
  if (sync is! bool) {
    throw const FormatException('CAREGIVER_SYNC_ENABLED must be a boolean.');
  }
  if (sync && (!enabled || !_allPresent(profile, _medicationKeys))) {
    throw const FormatException(
      'Medication sync requires complete public configuration.',
    );
  }
  if ((environment == 'staging' || environment == 'production') && sync) {
    throw const FormatException(
      'Named deployment profiles cannot enable medication sync.',
    );
  }
  final callback = _text(profile, 'APPWRITE_CALLBACK_SCHEME');
  final expected = enabled
      ? 'appwrite-callback-${_text(profile, 'APPWRITE_PROJECT_ID')}'
      : 'appwrite-callback-offline';
  if (callback != null && callback != expected) {
    throw const FormatException('Callback scheme is invalid.');
  }
  final origin = _text(profile, 'WEB_APP_ORIGIN');
  if (origin != null && !_validOrigin(origin)) {
    throw const FormatException('Web origin is invalid.');
  }
  if (!enabled && profile.keys.any(_cloudKeys.contains)) {
    throw const FormatException(
      'Offline profile contains cloud configuration.',
    );
  }
  return expected;
}

Future<void> _runFlutter(List<String> arguments) async {
  final separator = arguments.indexOf('--');
  if (separator < 0) {
    throw const FormatException(
      'flutter requires -- before Flutter arguments.',
    );
  }
  final options = arguments.take(separator).toList();
  final forwarded = arguments.skip(separator + 1).toList();
  final profilePath = _requiredOption(options, '--profile');
  final flavor = _requiredOption(options, '--flavor');
  if (!{'personal', 'robot'}.contains(flavor) ||
      forwarded.any((arg) => arg.startsWith('--dart-define'))) {
    throw const FormatException(
      'Use one profile and the selected flavor only.',
    );
  }
  validateNoPubAndroidBuildMetadata(
    forwarded,
    existingMetadata: {
      for (final path in _requiredNoPubAndroidBuildMetadata)
        if (File(path).existsSync()) path,
    },
  );
  validateProfile(loadProfile(profilePath));
  final result = await Process.start(
    'flutter',
    flutterArguments(
      flavor: flavor,
      profilePath: profilePath,
      forwarded: forwarded,
    ),
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await result.exitCode;
}

void validateNoPubAndroidBuildMetadata(
  List<String> forwarded, {
  required Set<String> existingMetadata,
}) {
  if (forwarded.isEmpty ||
      forwarded.first == 'run' ||
      !forwarded.contains('--no-pub')) {
    return;
  }
  final isAndroidBuild = List.generate(
    forwarded.length - 1,
    (index) =>
        forwarded[index] == 'build' &&
        {'apk', 'appbundle'}.contains(forwarded[index + 1]),
  ).contains(true);
  if (!isAndroidBuild) return;
  if (!_requiredNoPubAndroidBuildMetadata.every(existingMetadata.contains)) {
    throw const FormatException(
      'Android --no-pub builds require generated Flutter package metadata. Run flutter pub get first.',
    );
  }
}

List<String> flutterArguments({
  required String flavor,
  required String profilePath,
  required List<String> forwarded,
}) {
  _rejectNativeIosBuild(forwarded);
  final capability = flavor == 'personal' ? 'hardware-assisted' : 'phone-only';
  return [
    ...forwarded,
    '--flavor',
    flavor,
    '--dart-define-from-file=$profilePath',
    '--dart-define=DOSEY_BUILD_PROFILE=$flavor',
    '--dart-define=DOSEY_RUNTIME_CAPABILITY=$capability',
  ];
}

void _rejectNativeIosBuild(List<String> arguments) {
  if (arguments.length < 2) return;
  final isNativeIosBuild = List.generate(
    arguments.length - 1,
    (index) =>
        arguments[index] == 'build' &&
        {'ios', 'ipa'}.contains(arguments[index + 1]),
  ).contains(true);
  if (isNativeIosBuild) {
    throw const FormatException(
      'Native iOS builds are unsupported. Use the web app on iOS, iPadOS, and computers.',
    );
  }
}

String _requiredOption(List<String> arguments, String option) {
  final index = arguments.indexOf(option);
  if (index < 0 || index + 1 == arguments.length) {
    throw const FormatException('A required option is missing.');
  }
  return arguments[index + 1];
}

String? _text(Map<String, dynamic> profile, String key) {
  final value = profile[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Profile value is invalid.');
  }
  if (value.trim() != value) {
    throw const FormatException('Profile value is invalid.');
  }
  return value;
}

bool _validEndpoint(String value) {
  if (RegExp(r'^https://[^/?#]*(@|:[0-9]+/)').hasMatch(value)) return false;
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      !uri.authority.split('@').last.contains(':') &&
      uri.path == '/v1' &&
      !uri.hasQuery &&
      !uri.hasFragment;
}

bool _validOrigin(String value) {
  if (RegExp(r'^https://[^/?#]*(@|:[0-9]+/?$)').hasMatch(value)) return false;
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      !uri.authority.split('@').last.contains(':') &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      !uri.hasFragment;
}

void _requireComplete(Map<String, dynamic> profile, Set<String> keys) {
  final count = keys.where((key) => _text(profile, key) != null).length;
  if (count != 0 && count != keys.length) {
    throw const FormatException('A Function group is incomplete.');
  }
}

bool _allPresent(Map<String, dynamic> profile, Set<String> keys) =>
    keys.every((key) => _text(profile, key) != null);
