#!/usr/bin/env python3
import argparse
import os
import pathlib
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
import zipfile


CALLBACK = 'appwrite-callback-offline'
FORBIDDEN = (
    b'APPWRITE_API_KEY',
    b'APPWRITE_DYNAMIC_KEY',
    b'APPWRITE_FUNCTION_API_ENDPOINT',
    b'APPWRITE_FUNCTION_API_PROJECT_ID',
    b'APPWRITE_FUNCTION_PROJECT_ID',
    b'PAIRING_CREDENTIAL',
    b'DOSEY_DATABASE_ID',
)
FORBIDDEN_DOSEY_KEY = re.compile(
    rb'DOSEY_[A-Z0-9_]*(?:API_KEY|DYNAMIC_KEY|DATABASE_ID|TABLE_ID|COLLECTION_ID|BUCKET_ID|SECRET|CREDENTIAL|TOKEN|PRIVATE_KEY|HMAC_SECRET)'
)


def fail(message):
    raise SystemExit(message)


def apkanalyzer_path():
    tool = shutil.which('apkanalyzer')
    if tool:
        return tool
    root = os.environ.get('ANDROID_SDK_ROOT')
    if root:
        matches = sorted(pathlib.Path(root).glob('cmdline-tools/*/bin/apkanalyzer'))
        if matches:
            return str(matches[-1])
    fail('apkanalyzer is unavailable from PATH or ANDROID_SDK_ROOT.')


def decoded_manifest(apk):
    result = subprocess.run([apkanalyzer_path(), 'manifest', 'print', str(apk)], capture_output=True, text=True)
    if result.returncode:
        fail(f'apkanalyzer failed to decode APK manifest: {result.stderr.strip()}')
    return ET.fromstring(result.stdout)


def verify_personal_manifest(manifest):
    namespace = '{http://schemas.android.com/apk/res/android}'
    activities = [item for item in manifest.iter('activity') if item.attrib.get(namespace + 'name') == 'com.linusu.flutter_web_auth_2.CallbackActivity']
    if len(activities) != 1 or activities[0].attrib.get(namespace + 'exported') != 'true':
        fail('Personal APK callback activity is invalid.')
    filters = activities[0].findall('intent-filter')
    matches = []
    for intent_filter in filters:
        actions = {item.attrib.get(namespace + 'name') for item in intent_filter.findall('action')}
        categories = {item.attrib.get(namespace + 'name') for item in intent_filter.findall('category')}
        schemes = {item.attrib.get(namespace + 'scheme') for item in intent_filter.findall('data')}
        if actions == {'android.intent.action.VIEW'} and categories == {'android.intent.category.DEFAULT', 'android.intent.category.BROWSABLE'} and schemes == {CALLBACK}:
            matches.append(intent_filter)
    if len(matches) != 1 or sum(1 for item in manifest.iter() if item.attrib.get(namespace + 'scheme', '').startswith('appwrite-callback-')) != 1:
        fail('Personal APK callback intent filter is invalid.')


def verify_robot_manifest(manifest):
    namespace = '{http://schemas.android.com/apk/res/android}'
    if any(item.attrib.get(namespace + 'name') == 'com.linusu.flutter_web_auth_2.CallbackActivity' for item in manifest.iter('activity')) or any(item.attrib.get(namespace + 'scheme', '').startswith('appwrite-callback-') for item in manifest.iter()):
        fail('Robot Android manifest must not contain an Appwrite callback.')


def _verify_entry(name, contents):
    lowered = name.lower()
    if lowered.endswith('.env') or '/config/appwrite/' in lowered:
        fail('Client artifact contains a configuration profile.')
    if any(marker in contents for marker in FORBIDDEN) or FORBIDDEN_DOSEY_KEY.search(contents):
        fail('Client artifact contains a forbidden server configuration marker.')


def verify_zip_artifact(path):
    with zipfile.ZipFile(path) as archive:
        for info in archive.infolist():
            _verify_entry(info.filename, archive.read(info))


def _single(paths, label):
    if len(paths) != 1:
        fail(f'Expected one {label}; found {len(paths)}.')
    return paths[0]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--android', action='store_true')
    parser.add_argument('--build-type', choices=('debug', 'release'), default='debug')
    parser.add_argument('--root', type=pathlib.Path, default=pathlib.Path('.'))
    args = parser.parse_args()
    if not args.android:
        fail('Select the Android artifact platform.')
    root = args.root
    personal = _single(list(root.glob(f'build/app/outputs/flutter-apk/*personal*{args.build_type}.apk')), 'Personal APK')
    robot = _single(list(root.glob(f'build/app/outputs/flutter-apk/*robot*{args.build_type}.apk')), 'Robot APK')
    verify_personal_manifest(decoded_manifest(personal))
    verify_robot_manifest(decoded_manifest(robot))
    verify_zip_artifact(personal)
    verify_zip_artifact(robot)


if __name__ == '__main__':
    main()
