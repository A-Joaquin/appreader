import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/network_timeout.dart';
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

  /// Imágenes que se bajan a la vez. Una a una, un libro de 226 imágenes (el 1)
  /// paga la latencia del servidor 226 veces seguidas; en paralelo se solapan.
  /// 6 es suficiente para saturar una conexión móvil sin ahogarla.
  static const int _imageConcurrency = 6;

  /// Columnas que la app usa de verdad.
  ///
  /// `description` (el contexto que usó el LLM) y `translated` (la cola del
  /// pipeline) los ignora Flutter — ver FLUTTER_DB_CONTRACT §1 — y pesan entre
  /// el 17 % y el 77 % del payload de los fragments según el libro. Pedir `*`
  /// era descargar todo eso para tirarlo.
  static const String _fragmentColumns =
      'id,block_id,fragment_order,original_text,translated_text,'
      'char_start,char_end,word_map';
  static const String _blockColumns =
      'id,book_id,page_number,sequence_order,block_type,original_content,'
      'image_url';

  BaseCacheManager get _cache => DefaultCacheManager();

  /// Downloads [bookId]. [onProgress] reports 0.0–1.0 for a progress bar.
  ///
  /// Los tramos van repartidos por lo que TARDA cada fase, no por lo que ocupa
  /// en el código: las imágenes se llevan del 0.6 al 1.0 porque son la parte
  /// larga en los libros que tienen muchas.
  Future<void> download(int bookId, {void Function(double)? onProgress}) async {
    onProgress?.call(0.02);

    final bookResp = await _client
        .from('books')
        .select('*')
        .eq('id', bookId)
        .maybeSingle();
    if (bookResp == null) {
      throw StateError('El libro no existe.');
    }
    final book = Book.fromJson(bookResp);
    onProgress?.call(0.05);

    // All blocks of the book, ordered.
    final blocksResp = await _client
        .from('content_blocks')
        .select(_blockColumns)
        .eq('book_id', bookId)
        .order('sequence_order', ascending: true);
    final blocks = (blocksResp as List)
        .map((j) => ContentBlock.fromJson(j as Map<String, dynamic>))
        .toList();
    onProgress?.call(0.15);

    // All fragments for those blocks, fetched in chunks. El progreso avanza
    // chunk a chunk: antes saltaba de 0.3 a 0.6 de golpe y parecía colgado.
    final blockIds = blocks.map((b) => b.id).toList();
    final fragments = <BlockFragment>[];
    final chunks = (blockIds.length / _chunkSize).ceil();
    for (var i = 0; i < blockIds.length; i += _chunkSize) {
      final chunk = blockIds.sublist(
        i,
        (i + _chunkSize > blockIds.length) ? blockIds.length : i + _chunkSize,
      );
      final resp = await _client
          .from('block_fragments')
          .select(_fragmentColumns)
          .inFilter('block_id', chunk)
          .order('fragment_order', ascending: true);
      fragments.addAll(
        (resp as List)
            .map((j) => BlockFragment.fromJson(j as Map<String, dynamic>)),
      );
      final done = (i ~/ _chunkSize) + 1;
      onProgress?.call(0.15 + 0.40 * (done / (chunks == 0 ? 1 : chunks)));
    }

    await _local.saveBook(book: book, blocks: blocks, fragments: fragments);
    onProgress?.call(0.60);

    // Report the download to the server (best-effort) so the admin panel knows
    // which books each user has offline. Never aborts the download.
    final uid = _client.auth.currentUser?.id;
    if (uid != null) {
      try {
        await _client.from('user_downloads').upsert({
          'user_id': uid,
          'book_id': bookId,
          'downloaded_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,book_id').timeout(kNetworkTimeout);
      } catch (_) {
        // Offline or transient error: local download already succeeded.
      }
    }

    await cacheImages(
      imageUrlsOf(blocks),
      onProgress: (fraction) => onProgress?.call(0.60 + 0.40 * fraction),
    );

    onProgress?.call(1.0);
  }

  /// URLs de las imágenes de [blocks], sin repetir.
  static List<String> imageUrlsOf(List<ContentBlock> blocks) {
    final seen = <String>{};
    for (final block in blocks) {
      final url = block.imageUrl;
      if (block.blockType == 'image' && url != null && url.isNotEmpty) {
        seen.add(url);
      }
    }
    return seen.toList();
  }

  /// Las imágenes del libro que AÚN NO están en la caché.
  ///
  /// Se pregunta a la caché en vez de llevar la cuenta en la base: así la
  /// respuesta es correcta aunque la descarga se cortara a la mitad, aunque el
  /// sistema hubiera vaciado la caché por su cuenta, o aunque la app se cerrara
  /// de golpe. Se cura sola.
  ///
  /// En web devuelve siempre vacío: allí `flutter_cache_manager` guarda en
  /// memoria (`MemoryCacheSystem`), así que no hay nada que verificar ni que
  /// conservar entre recargas.
  Future<List<String>> missingImages(int bookId) async {
    if (kIsWeb) return const [];
    final missing = <String>[];
    for (final url in (await _local.getImageUrls(bookId)).toSet()) {
      final hit = await _cache.getFileFromCache(url);
      if (hit == null) missing.add(url);
    }
    return missing;
  }

  /// Baja [urls] a la caché de imágenes, [_imageConcurrency] a la vez.
  ///
  /// Una imagen que falla no aborta el resto: se reintentará la próxima vez,
  /// porque [missingImages] la volverá a ver como ausente.
  Future<void> cacheImages(
    List<String> urls, {
    void Function(double fraction)? onProgress,
  }) async {
    // En web la caché vive en memoria: bajarlas aquí no las deja disponibles
    // sin conexión y solo gasta datos. Las sirve el navegador al mostrarlas.
    if (kIsWeb || urls.isEmpty) {
      onProgress?.call(1);
      return;
    }

    var next = 0;
    var done = 0;

    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= urls.length) return;
        try {
          await _cache.downloadFile(urls[index]);
        } catch (_) {
          // Una imagen caída no debe tumbar la descarga entera.
        }
        done++;
        onProgress?.call(done / urls.length);
      }
    }

    final workers = urls.length < _imageConcurrency
        ? urls.length
        : _imageConcurrency;
    await Future.wait([for (var i = 0; i < workers; i++) worker()]);
  }
}
