import 'package:drift/drift.dart';

/// Fallback for platforms that have neither `dart:io` nor `dart:html`.
/// In practice this is never reached in a Flutter app.
QueryExecutor openConnection() {
  throw UnsupportedError(
    'No database connection is available for this platform.',
  );
}
