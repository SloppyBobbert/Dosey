# Third-party runtime assets

The web database bootstrap requires these files at runtime. Drift loads the
worker and SQLite loads the WebAssembly module from the app's `web/` directory.

| Asset | Version | Upstream | Size | SHA-256 |
| --- | --- | --- | ---: | --- |
| `sqlite3.wasm` | sqlite3.dart 3.3.2 | https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.3.2/sqlite3.wasm | 744131 bytes | `cb6b6b3a6d6cd912ef3b95ab995714a4e91694aa9a9d1cd15542314fb44982d0` |
| `drift_worker.js` | drift 2.33.0 | https://github.com/simolus3/drift/releases/download/drift-2.33.0/drift_worker.js | 351222 bytes | `6b988b72ff5c4fd90b78daf4b8b112c0c2fd45d3b4032519317e0fe28b7d1785` |
