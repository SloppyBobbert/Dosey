import hashlib
import json
import platform
import shutil
from pathlib import Path

flutter = shutil.which('flutter')
if flutter is None:
    raise SystemExit('flutter not found on PATH')
sdk = Path(flutter).resolve().parents[1]
print('uname:', platform.uname())
print('flutter_sdk:', sdk)
version = json.loads((sdk / 'bin/cache/flutter.version.json').read_text())
for key in ('flutterVersion', 'frameworkRevision', 'engineRevision',
            'engineContentHash', 'dartSdkVersion'):
    print(f'{key}: {version.get(key, "missing")}')
for relative in ('bin/internal/engine.version', 'bin/cache/engine.stamp'):
    path = sdk / relative
    print(f'{relative}: {path.read_text().strip() if path.is_file() else "missing"}')
files = [sdk / 'bin/cache/artifacts/material_fonts' / name for name in
         ('Roboto-Regular.ttf', 'MaterialIcons-Regular.otf')]
files += sorted((sdk / 'bin/cache/artifacts/engine').glob('*/flutter_tester'))
if len(files) == 2:
    print('flutter_tester: missing')
for path in files:
    digest = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else 'missing'
    print(f'sha256 {path.relative_to(sdk)}: {digest}')
print(f'sha256 pubspec.lock: {hashlib.sha256(Path("pubspec.lock").read_bytes()).hexdigest()}')
