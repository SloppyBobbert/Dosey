"""Small offline assembler contract. Synthetic files are not build evidence."""
import json
from pathlib import Path
import tempfile

import assemble_local_personal as assembler


def main():
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        compiled = root / 'compiled'
        for name in assembler.REQUIRED:
            path = compiled / name
            path.parent.mkdir(parents=True, exist_ok=True)
            if name in ('sqlite3.wasm', 'drift_worker.js'):
                path.write_bytes((assembler.APP / 'web' / name).read_bytes())
            else:
                path.write_text('[]' if name.endswith('FontManifest.json') else 'fictional compiled fixture')
        (compiled / 'flutter_bootstrap.js').write_text(
            '_flutter.buildConfig = {"useLocalCanvasKit":true};\n_flutter.loader.load({serviceWorkerSettings:{}});')
        (compiled / 'auth.html').write_text('must not copy')
        output = root / 'site/local'
        receipt = assembler.assemble(compiled, output)
        assert not (output / 'auth.html').exists()
        assert receipt['compiled_main_sha256'] == assembler.sha(output / 'main.dart.js')
        assert all(assembler.sha(output / name) == value for name, value in receipt['files'].items())
        loader = (output / 'flutter_bootstrap.js').read_text()
        assert 'serviceWorkerSettings' not in loader
        assert "fontFallbackBaseUrl: '/local/assets/local_fonts/'" in loader.replace('"', "'")
        assert "canvasKitBaseUrl: '/local/canvaskit/'" in loader.replace('"', "'")
        html = (output / 'index.html').read_text()
        assert html.index('Content-Security-Policy') < html.index('<script')
        assert "script-src 'self' 'wasm-unsafe-eval'" in html
        assert "font-src 'self'" in html and '<base href="/local/">' in html
        assert 'https:' not in html
        fonts = json.loads((output / 'assets/FontManifest.json').read_text())
        assert {entry['family'] for entry in fonts} >= {'Roboto', 'DoseyLocalRoboto'}
        for entry in fonts:
            for font in entry['fonts']:
                assert (output / 'assets' / font['asset']).stat().st_size > 0
        try:
            assembler.assemble(compiled, output)
            raise AssertionError('Existing artifact was overwritten')
        except ValueError:
            pass
        # A failure after the copy started must publish nothing and stay retryable.
        (compiled / 'assets/.env').write_text('must be rejected')
        try:
            assembler.assemble(compiled, root / 'failed')
            raise AssertionError('Environment artifact was accepted')
        except ValueError:
            assert not (root / 'failed').exists(), 'partial output was published'
            assert not [
                path for path in root.iterdir() if path.name.startswith('.failed')
            ], 'staging directory was left behind'
        (compiled / 'assets/.env').unlink()
        assert assembler.assemble(compiled, root / 'failed')['files']
        assert (root / 'failed/local-assets.json').is_file()
        (compiled / 'flutter_bootstrap.js').write_text('changed loader contract')
        try:
            assembler.assemble(compiled, root / 'rejected')
            raise AssertionError('Unknown generated loader was accepted')
        except ValueError:
            assert not (root / 'rejected').exists()
    print('PASS: local CSP, fonts, asset hashes, caregiver exclusion, immutable output, fail-closed loader shape, atomic publish retry (synthetic fixture only)')


if __name__ == '__main__':
    main()
