import importlib.util
import pathlib
import tempfile
import unittest
import zipfile
import xml.etree.ElementTree as ET


SCRIPT = pathlib.Path(__file__).with_name('verify_public_config_artifacts.py')
SPEC = importlib.util.spec_from_file_location('verify_artifacts', SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError('Unable to load artifact verifier.')
verify_artifacts = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verify_artifacts)


class ArtifactVerificationTest(unittest.TestCase):
    def manifest(self, callback=True, exported='true'):
        scheme = '<data android:scheme="appwrite-callback-offline"/>' if callback else ''
        return ET.fromstring(f'''<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application><activity android:name="com.linusu.flutter_web_auth_2.CallbackActivity" android:exported="{exported}"><intent-filter><action android:name="android.intent.action.VIEW"/><category android:name="android.intent.category.DEFAULT"/><category android:name="android.intent.category.BROWSABLE"/>{scheme}</intent-filter></activity></application></manifest>''')

    def test_personal_manifest_requires_expected_callback(self):
        verify_artifacts.verify_personal_manifest(self.manifest())

    def test_robot_manifest_rejects_callback(self):
        with self.assertRaises(SystemExit):
            verify_artifacts.verify_robot_manifest(self.manifest())

    def test_apk_rejects_profile_and_server_markers(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = pathlib.Path(directory, 'app.apk')
            with zipfile.ZipFile(apk, 'w') as archive:
                archive.writestr('assets/config/appwrite/offline.json', '{}')
            with self.assertRaises(SystemExit):
                verify_artifacts.verify_zip_artifact(apk)

            with zipfile.ZipFile(apk, 'w') as archive:
                archive.writestr('classes.dex', 'DOSEY_PAIRING_HMAC_SECRET')
            with self.assertRaises(SystemExit):
                verify_artifacts.verify_zip_artifact(apk)

    def test_apk_allows_unrelated_platform_markers(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = pathlib.Path(directory, 'app.apk')
            with zipfile.ZipFile(apk, 'w') as archive:
                archive.writestr('classes.dex', 'TABLE_ID HMAC')
            verify_artifacts.verify_zip_artifact(apk)

    def test_apk_rejects_bounded_server_markers(self):
        for marker in [
            'APPWRITE_FUNCTION_API_ENDPOINT', 'APPWRITE_FUNCTION_PROJECT_ID', 'APPWRITE_DYNAMIC_KEY',
            'DOSEY_SYNC_TABLE_ID', 'DOSEY_PRIVATE_KEY',
            'DOSEY_PAIRING_CREDENTIAL', 'DOSEY_HMAC_SECRET',
        ]:
            with tempfile.TemporaryDirectory() as directory:
                apk = pathlib.Path(directory, 'app.apk')
                with zipfile.ZipFile(apk, 'w') as archive:
                    archive.writestr('classes.dex', marker)
                with self.assertRaises(SystemExit):
                    verify_artifacts.verify_zip_artifact(apk)


if __name__ == '__main__':
    unittest.main()
