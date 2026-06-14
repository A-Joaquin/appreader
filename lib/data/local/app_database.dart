import 'package:drift/drift.dart';

import 'connection/connection.dart';

part 'app_database.g.dart';

/// Mirrors `books`. A row here means the book is downloaded for offline use.
class LocalBooks extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  IntColumn get totalPages => integer().nullable()();
  TextColumn get language => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  DateTimeColumn get downloadedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mirrors `content_blocks`.
class LocalBlocks extends Table {
  IntColumn get id => integer()();
  IntColumn get bookId => integer()();
  IntColumn get pageNumber => integer().nullable()();
  IntColumn get sequenceOrder => integer().nullable()();
  TextColumn get blockType => text()();
  TextColumn get originalContent => text().nullable()();
  TextColumn get imageUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mirrors `block_fragments`. `word_map` is stored as the raw JSON string.
class LocalFragments extends Table {
  IntColumn get id => integer()();
  IntColumn get blockId => integer()();
  IntColumn get fragmentOrder => integer()();
  TextColumn get originalText => text()();
  TextColumn get translatedText => text().nullable()();
  IntColumn get charStart => integer().nullable()();
  IntColumn get charEnd => integer().nullable()();
  TextColumn get wordMapJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [LocalBooks, LocalBlocks, LocalFragments])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  /// Single shared instance for the whole app.
  static final AppDatabase instance = AppDatabase();

  @override
  int get schemaVersion => 1;
}
