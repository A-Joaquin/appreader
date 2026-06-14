import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/block_fragment_model.dart';
import '../models/book_model.dart';
import '../models/content_block_model.dart';
import 'app_database.dart';

/// High-level offline store. Translates between Drift rows and the domain
/// models the rest of the app already uses, so blocs/UI don't change.
class LocalBookStore {
  LocalBookStore(this._db);

  final AppDatabase _db;

  Future<bool> isDownloaded(int bookId) async {
    final query = _db.select(_db.localBooks)..where((t) => t.id.equals(bookId));
    return (await query.getSingleOrNull()) != null;
  }

  Future<Set<int>> downloadedBookIds() async {
    final rows = await _db.select(_db.localBooks).get();
    return rows.map((r) => r.id).toSet();
  }

  Future<Book?> getBook(int bookId) async {
    final query = _db.select(_db.localBooks)..where((t) => t.id.equals(bookId));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toBook(row);
  }

  /// All downloaded books, newest download first — used as the offline fallback
  /// for the library list and the reader drawer.
  Future<List<Book>> getDownloadedBooks() async {
    final query = _db.select(_db.localBooks)
      ..orderBy([
        (t) => OrderingTerm(
              expression: t.downloadedAt,
              mode: OrderingMode.desc,
            ),
      ]);
    final rows = await query.get();
    return rows.map(_toBook).toList();
  }

  Book _toBook(LocalBook r) => Book(
        id: r.id,
        title: r.title,
        author: r.author,
        totalPages: r.totalPages,
        language: r.language,
        coverUrl: r.coverUrl,
      );

  Future<List<ContentBlock>> getPageBlocks(int bookId, int pageNumber) async {
    final query = _db.select(_db.localBlocks)
      ..where((t) => t.bookId.equals(bookId) & t.pageNumber.equals(pageNumber))
      ..orderBy([(t) => OrderingTerm(expression: t.sequenceOrder)]);
    final rows = await query.get();
    return rows.map(_toBlock).toList();
  }

  /// Image URLs of a downloaded book, in reading order — used to pick a cover
  /// offline. Mirrors [BookRepository.getBookImageUrls] for downloaded books.
  Future<List<String>> getImageUrls(int bookId) async {
    final query = _db.select(_db.localBlocks)
      ..where((t) => t.bookId.equals(bookId) & t.blockType.equals('image'))
      ..orderBy([
        (t) => OrderingTerm(expression: t.pageNumber),
        (t) => OrderingTerm(expression: t.sequenceOrder),
      ]);
    final rows = await query.get();
    return rows
        .map((r) => r.imageUrl)
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
  }

  Future<List<BlockFragment>> getFragmentsForBlocks(List<int> blockIds) async {
    if (blockIds.isEmpty) return [];
    final query = _db.select(_db.localFragments)
      ..where((t) => t.blockId.isIn(blockIds));
    final rows = await query.get();
    return rows.map(_toFragment).toList();
  }

  /// Stores a full book (metadata + all blocks + all fragments) for offline
  /// reading, replacing any previous copy.
  Future<void> saveBook({
    required Book book,
    required List<ContentBlock> blocks,
    required List<BlockFragment> fragments,
  }) async {
    await _db.transaction(() async {
      await _deleteBookContent(book.id);

      await _db.into(_db.localBooks).insertOnConflictUpdate(
            LocalBooksCompanion.insert(
              id: Value(book.id),
              title: book.title,
              author: Value(book.author),
              totalPages: Value(book.totalPages),
              language: Value(book.language),
              coverUrl: Value(book.coverUrl),
              downloadedAt: DateTime.now(),
            ),
          );

      await _db.batch((batch) {
        batch.insertAll(
          _db.localBlocks,
          blocks.map(
            (b) => LocalBlocksCompanion.insert(
              id: Value(b.id),
              bookId: b.bookId,
              pageNumber: Value(b.pageNumber),
              sequenceOrder: Value(b.sequenceOrder),
              blockType: b.blockType,
              originalContent: Value(b.originalContent),
              imageUrl: Value(b.imageUrl),
            ),
          ),
        );
        batch.insertAll(
          _db.localFragments,
          fragments.map(
            (f) => LocalFragmentsCompanion.insert(
              id: Value(f.id),
              blockId: f.blockId,
              fragmentOrder: f.fragmentOrder,
              originalText: f.originalText,
              translatedText: Value(f.translatedText),
              charStart: Value(f.charStart),
              charEnd: Value(f.charEnd),
              wordMapJson: Value(_encodeWordMap(f)),
            ),
          ),
        );
      });
    });
  }

  Future<void> deleteBook(int bookId) async {
    await _db.transaction(() async {
      await _deleteBookContent(bookId);
      await (_db.delete(_db.localBooks)..where((t) => t.id.equals(bookId))).go();
    });
  }

  /// Deletes a book's blocks and their fragments (but not the book row).
  Future<void> _deleteBookContent(int bookId) async {
    final blockRows = await (_db.select(_db.localBlocks)
          ..where((t) => t.bookId.equals(bookId)))
        .get();
    final ids = blockRows.map((r) => r.id).toList();
    if (ids.isNotEmpty) {
      await (_db.delete(_db.localFragments)..where((t) => t.blockId.isIn(ids)))
          .go();
    }
    await (_db.delete(_db.localBlocks)..where((t) => t.bookId.equals(bookId)))
        .go();
  }

  static String? _encodeWordMap(BlockFragment f) {
    if (f.wordMap.isEmpty) return null;
    return jsonEncode(f.wordMap.map((e) => e.toJson()).toList());
  }

  ContentBlock _toBlock(LocalBlock r) => ContentBlock.fromJson({
        'id': r.id,
        'book_id': r.bookId,
        'page_number': r.pageNumber,
        'sequence_order': r.sequenceOrder,
        'block_type': r.blockType,
        'original_content': r.originalContent,
        'image_url': r.imageUrl,
      });

  BlockFragment _toFragment(LocalFragment r) => BlockFragment.fromJson({
        'id': r.id,
        'block_id': r.blockId,
        'fragment_order': r.fragmentOrder,
        'original_text': r.originalText,
        'translated_text': r.translatedText,
        'char_start': r.charStart,
        'char_end': r.charEnd,
        'word_map':
            r.wordMapJson != null ? jsonDecode(r.wordMapJson!) as List : null,
      });
}
