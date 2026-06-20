import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Web: SQLite compiled to WebAssembly, persisted in the browser (IndexedDB /
/// OPFS depending on what the browser supports). Requires `sqlite3.wasm` and
/// `drift_worker.js` to be present in the `web/` folder (served at the app root).
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'blackreader',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
