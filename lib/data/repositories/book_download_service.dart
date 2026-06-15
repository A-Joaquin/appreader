import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/local_book_store.dart';
import '../models/block_fragment_model.dart';
import '../models/book_model.dart';
import '../models/content_block_model.dart';

/// Downloads a whole book (all pages) from Supabase into the local store for
/// offline reading, including pre-caching its images.
class BookDownloadService {
  BookDownloadService(this._client, this._local);

  final SupabaseClient _client;
  final LocalBookStore _local;

  /// Supabase `IN (...)` lists are kept to this size to stay well within limits.
  static const int _chunkSize = 200;

  /// Downloads [bookId]. [onProgress] reports 0.0–1.0 for a progress bar.
  Future<void> download(int bookId, {void Function(double)? onProgress}) async {
    onProgress?.call(0.05);

    final bookResp = await _client
        .from('books')
        .select('*')
        .eq('id', bookId)
        .maybeSingle();
    if (bookResp == null) {
      throw StateError('El libro no existe.');
    }
    final book = Book.fromJson(bookResp);

    // All blocks of the book, ordered.
    final blocksResp = await _client
        .from('content_blocks')
        .select('*')
        .eq('book_id', bookId)
        .order('sequence_order', ascending: true);
    final blocks = (blocksResp as List)
        .map((j) => ContentBlock.fromJson(j as Map<String, dynamic>))
        .toList();
    onProgress?.call(0.3);

    // All fragments for those blocks, fetched in chunks.
    final blockIds = blocks.map((b) => b.id).toList();
    final fragments = <BlockFragment>[];
    for (var i = 0; i < blockIds.length; i += _chunkSize) {
      final chunk = blockIds.sublist(
        i,
        (i + _chunkSize > blockIds.length) ? blockIds.length : i + _chunkSize,
      );
      final resp = await _client
          .from('block_fragments')
          .select('*')
          .inFilter('block_id', chunk)
          .order('fragment_order', ascending: true);
      fragments.addAll(
        (resp as List)
            .map((j) => BlockFragment.fromJson(j as Map<String, dynamic>)),
      );
    }
    onProgress?.call(0.6);

    await _local.saveBook(book: book, blocks: blocks, fragments: fragments);
    onProgress?.call(0.7);

    // Report the download to the server (best-effort) so the admin panel knows
    // which books each user has offline. Never aborts the download.
    final uid = _client.auth.currentUser?.id;
    if (uid != null) {
      try {
        await _client.from('user_downloads').upsert({
          'user_id': uid,
          'book_id': bookId,
          'downloaded_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,book_id');
      } catch (_) {
        // Offline or transient error: local download already succeeded.
      }
    }

    // Pre-cache images so they render offline (cached_network_image reads from
    // the same DefaultCacheManager).
    final imageUrls = blocks
        .where((b) => b.blockType == 'image' && (b.imageUrl?.isNotEmpty ?? false))
        .map((b) => b.imageUrl!)
        .toList();
    for (var i = 0; i < imageUrls.length; i++) {
      try {
        await DefaultCacheManager().downloadFile(imageUrls[i]);
      } catch (_) {
        // A failed image shouldn't abort the whole download.
      }
      onProgress?.call(0.7 + 0.3 * ((i + 1) / imageUrls.length));
    }

    onProgress?.call(1.0);
  }
}
