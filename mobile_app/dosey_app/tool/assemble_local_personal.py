"""Assemble a fresh /local/ artifact from a main_web_local.dart Flutter build.

This does not build, download, serve, or deploy. The caller owns source/build
provenance. Keep the caregiver build unchanged; put this output beside it.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

APP = Path(__file__).resolve().parents[1]
STATIC = APP / 'tool/local_personal'
REQUIRED = ('main.dart.js', 'sqlite3.wasm', 'drift_worker.js',
            'canvaskit/canvaskit.js', 'canvaskit/canvaskit.wasm',
            'assets/FontManifest.json')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def assemble(compiled, output):
    compiled, output = compiled.resolve(), output.resolve()
    if output.exists() or output == compiled or compiled in output.parents:
        raise ValueError('Output must be new and outside the compiled build')
    for name in REQUIRED:
        if not (compiled / name).is_file() or not (compiled / name).stat().st_size:
            raise ValueError(f'Missing compiled local resource: {name}')
    for name in ('sqlite3.wasm', 'drift_worker.js'):
        if sha(compiled / name) != sha(APP / 'web' / name):
            raise ValueError(f'Storage resource differs from source: {name}')
    bootstrap = (compiled / 'flutter_bootstrap.js').read_text()
    marker = '\n_flutter.loader.load('
    if bootstrap.count(marker) != 1:
        raise ValueError('Generated loader shape changed; review before assembly')
    prefix = bootstrap.split(marker)[0]
    if '"useLocalCanvasKit":true' not in prefix:
        raise ValueError('Compile with --no-web-resources-cdn')
    output.mkdir(parents=True)
    # Allowlist excludes caregiver entry pages and their auth configuration.
    for name in ('main.dart.js', 'sqlite3.wasm', 'drift_worker.js'):
        shutil.copyfile(compiled / name, output / name)
    for name in ('assets', 'canvaskit'):
        shutil.copytree(compiled / name, output / name)
    shutil.copytree(STATIC / 'assets/local_fonts', output / 'assets/local_fonts')
    font_manifest = output / 'assets/FontManifest.json'
    fonts = json.loads(font_manifest.read_text())
    for family in ('Roboto', 'DoseyLocalRoboto'):
        fonts = [entry for entry in fonts if entry['family'] != family]
        fonts.append({'family': family, 'fonts': [
            {'asset': 'local_fonts/Roboto-Regular.ttf'},
            {'asset': 'local_fonts/Roboto-Bold.ttf', 'weight': 700},
        ]})
    font_manifest.write_text(json.dumps(fonts) + '\n')
    shutil.copyfile(STATIC / 'index.html', output / 'index.html')
    (output / 'flutter_bootstrap.js').write_text(prefix + '\n' + (STATIC / 'flutter_loader.js').read_text())
    files = {str(p.relative_to(output)): sha(p) for p in sorted(output.rglob('*')) if p.is_file()}
    if any(Path(n).name == '.env' or Path(n).name.startswith('.env.') for n in files):
        raise ValueError('Unexpected environment artifact')
    receipt = {'compiled_main_sha256': sha(compiled / 'main.dart.js'),
               'compiled_bootstrap_sha256': sha(compiled / 'flutter_bootstrap.js'),
               'assembler_sha256': sha(Path(__file__)), 'files': files}
    (output / 'local-assets.json').write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('compiled', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    receipt = assemble(args.compiled, args.output)
    print(f'Assembled {len(receipt["files"])} local files; no server or browser started.')
