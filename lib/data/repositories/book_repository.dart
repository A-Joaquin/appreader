import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_database.dart';
import '../local/local_book_store.dart';
import '../models/book_model.dart';
import 'cover_store.dart';

class BookRepository {
  BookRepository(this.client, {LocalBookStore? local})
      : _local = local ?? LocalBookStore(AppDatabase.instance);

  final SupabaseClient client;
  final LocalBookStore _local;

  /// Caches each book's first image URL so resolving the cover on every list
  /// rebuild doesn't re-query. Shared across instances (the repository is
  /// constructed ad hoc in widgets).
  static final Map<int, String?> _firstImageCache = {};

  /// All image URLs of a book in reading order (offline-aware). Used both to
  /// pick the default cover and to let the user choose a different image.
  Future<List<String>> getBookImageUrls(int bookId) async {
    if (await _local.isDownloaded(bookId)) {
      return _local.getImageUrls(bookId);
    }
    final response = await client
        .from('content_blocks')
        .select('image_url')
        .eq('book_id', bookId)
        .eq('block_type', 'image')
        .order('page_number', ascending: true)
        .order('sequence_order', ascending: true);
    return (response as List)
        .map((json) => (json as Map<String, dynamic>)['image_url'] as String?)
        .where((url) => url != null && url.isNotEmpty)
        .cast<String>()
        .toList();
  }

  /// The book's first image URL (cached), or null when it has no images.
  Future<String?> getFirstImageUrl(int bookId) async {
    if (_firstImageCache.containsKey(bookId)) return _firstImageCache[bookId];
    final urls = await getBookImageUrls(bookId);
    final first = urls.isNotEmpty ? urls.first : null;
    _firstImageCache[bookId] = first;
    return first;
  }

  /// Resolves which image to show as a book's cover, in priority order:
  /// the user's chosen override → the book's `cover_url` → its first image →
  /// null (callers then show the initials placeholder).
  Future<String?> resolveCoverUrl(Book book) async {
    final override = await CoverStore().getOverride(book.id);
    if (override != null) return override;
    final cover = book.coverUrl;
    if (cover != null && cover.isNotEmpty) return cover;
    return getFirstImageUrl(book.id);
  }

  /// Library list. Falls back to downloaded books when the network is
  /// unavailable, so the home list and reader drawer still work offline.
  Future<List<Book>> getBooks() async {
    try {
      final response = await client
          .from('books')
          .select('*')
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => Book.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final downloaded = await _local.getDownloadedBooks();
      if (downloaded.isNotEmpty) return downloaded;
      rethrow;
    }
  }

  Future<Book?> getBookById(int id) async {
    // Offline-first: a downloaded book has its metadata (incl. total_pages)
    // stored locally, so the reader doesn't need the network just to page.
    if (await _local.isDownloaded(id)) {
      return _local.getBook(id);
    }

    final response =
        await client.from('books').select('*').eq('id', id).maybeSingle();

    if (response == null) return null;
    return Book.fromJson(response);
  }
}
