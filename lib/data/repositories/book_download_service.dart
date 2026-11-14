import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/network_timeout.dart';
import '../audio/block_audio.dart';
import '../local/local_book_store.dart';
import '../local/offline_cache.dart';
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

  /// Filas por petición al leer una tabla entera. PostgREST corta cada
  /// respuesta en 1000 filas SIN avisar (max-rows del proyecto): pedir todos
  /// los bloques de un libro de una vez dejaba fuera todo lo que pasara de
  /// 1000 (el libro 1 tiene 1508; sin conexión se perdía el final).
  static const int _pageSize = 1000;

  /// Imágenes que se bajan a la vez. Una a una, un libro de 226 imágenes (el 1)
  /// paga la latencia del servidor 226 veces seguidas; en paralelo se solapan.
  /// 6 es suficiente para saturar una conexión móvil sin ahogarla.
  static const int _imageConcurrency = 6;

  /// Intentos por archivo (imagen o audio) antes de darlo por fallido. Con la
  /// red del móvil un corte suelto es normal; sin reintento esa imagen se
  /// quedaba fuera hasta que alguien tocara «Completar descarga».
  static const int _fileAttempts = 3;

  /// Tope por archivo: un socket colgado dejaba la descarga en el mismo % para
  /// siempre, y como [DownloadManager] no arranca otra mientras siga viva, ni
  /// siquiera se podía reintentar.
  static const Duration _fileTimeout = Duration(seconds: 60);

  /// Lo mismo para cada petición a la base durante la descarga. Más largo que
  /// [kNetworkTimeout] porque aquí se bajan cientos de filas por petición.
  static const Duration _queryTimeout = Duration(seconds: 60);

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
      'image_url,audio_path,audio_ms,audio_words';

  /// Caché propia de las imágenes de los libros (ver [BookImages]).
  BaseCacheManager get _cache => BookImages.cache;

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
        .maybeSingle()
        .timeout(_queryTimeout);
    if (bookResp == null) {
      throw StateError('El libro no existe.');
    }
    final book = Book.fromJson(bookResp);
    onProgress?.call(0.05);

    // All blocks of the book, ordered, page by page (see [_pageSize]).
    final blocks = <ContentBlock>[];
    while (true) {
      final resp = await _client
          .from('content_blocks')
          .select(_blockColumns)
          .eq('book_id', bookId)
          .order('sequence_order', ascending: true)
          .order('id', ascending: true)
          .range(blocks.length, blocks.length + _pageSize - 1)
          .timeout(_queryTimeout);
      final page = (resp as List)
          .map((j) => ContentBlock.fromJson(j as Map<String, dynamic>))
          .toList();
      blocks.addAll(page);
      if (page.length < _pageSize) break;
    }
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
      // También por tramos: 200 bloques suelen ser ~400 fragmentos, pero un
      // tramo de bloques largos puede pasar de 1000 y PostgREST cortaría ahí
      // sin avisar, dejando bloques sin traducción.
      for (var from = 0;; from += _pageSize) {
        final resp = await _client
            .from('block_fragments')
            .select(_fragmentColumns)
            .inFilter('block_id', chunk)
            .order('block_id', ascending: true)
            .order('fragment_order', ascending: true)
            .order('id', ascending: true)
            .range(from, from + _pageSize - 1)
            .timeout(_queryTimeout);
        final page = (resp as List)
            .map((j) => BlockFragment.fromJson(j as Map<String, dynamic>))
            .toList();
        fragments.addAll(page);
        if (page.length < _pageSize) break;
      }
      final done = (i ~/ _chunkSize) + 1;
      onProgress?.call(0.15 + 0.40 * (done / (chunks == 0 ? 1 : chunks)));
    }

    await _local.saveBook(book: book, blocks: blocks, fragments: fragments);
    onProgress?.call(0.60);

    // Solo las que falten: al actualizar una descarga no se vuelven a bajar
    // las que ya están en el móvil.
    await cacheImages(
      await missingImages(bookId),
      onProgress: (fraction) => onProgress?.call(0.60 + 0.40 * fraction),
    );

    onProgress?.call(1.0);
  }

  /// Apunta en el servidor que [userId] tiene [bookId] descargado, para que el
  /// panel de admin sepa qué libros tiene cada uno sin conexión. Va aparte de
  /// [download] porque en segundo plano no hay sesión: allí se llama con un
  /// cliente que lleva el token del usuario. Nunca lanza: si falla, el libro
  /// ya está descargado igual.
  Future<void> reportDownload(int bookId, String userId) async {
    try {
      await _client.from('user_downloads').upsert({
        'user_id': userId,
        'book_id': bookId,
        'downloaded_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,book_id').timeout(kNetworkTimeout);
    } catch (_) {
      // Sin red o error pasajero: la descarga local ya está hecha.
    }
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
      if (await _cache.getFileFromCache(url) != null) continue;
      if (await _recoverLegacyImage(url)) continue;
      missing.add(url);
    }
    return missing;
  }

  /// Copia [url] de la caché de antes ([BookImages.legacy]) a la nueva, si
  /// todavía sigue allí. Así los libros ya descargados no tienen que volver a
  /// bajar las imágenes que no llegó a borrar la limpieza.
  Future<bool> _recoverLegacyImage(String url) async {
    try {
      final old = await BookImages.legacy.getFileFromCache(url);
      if (old == null) return false;
      final ext = p.extension(Uri.parse(url).path).replaceFirst('.', '');
      await _cache.putFile(
        url,
        await old.file.readAsBytes(),
        fileExtension: ext.isEmpty ? 'file' : ext,
      );
      await BookImages.legacy.removeFile(url);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Borra del móvil las imágenes del libro (al eliminar la descarga). Las
  /// URLs llevan el id del libro, así que no se pisan con las de otro.
  Future<void> deleteImages(int bookId) async {
    for (final url in (await _local.getImageUrls(bookId)).toSet()) {
      await _cache.removeFile(url);
    }
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
    await _cacheAll(urls, _cache, onProgress);
  }

  /// Audio en inglés de un libro YA descargado que aún no está en el móvil,
  /// con su duración total en ms (para avisar de cuánto ocupa antes de bajarlo).
  ///
  /// Va aparte de [download] a propósito: el audio pesa decenas de MB por
  /// libro y no todo el que lee quiere escuchar. Igual que [missingImages],
  /// pregunta a la caché, así que se cura sola si la descarga se cortó.
  Future<({List<String> urls, int totalMs, int missingMs})> audioStatus(
    int bookId,
  ) async {
    final audio = await _local.getAudio(bookId);
    final totalMs = audio.values.fold(0, (a, b) => a + b);
    if (kIsWeb) return (urls: const <String>[], totalMs: totalMs, missingMs: 0);
    final missing = <String>[];
    var missingMs = 0;
    for (final entry in audio.entries) {
      final url = BlockAudio.urlFor(entry.key);
      if (await BlockAudio.cache.getFileFromCache(url) == null) {
        missing.add(url);
        missingMs += entry.value;
      }
    }
    return (urls: missing, totalMs: totalMs, missingMs: missingMs);
  }

  /// Bloques del libro que están en el servidor y no en el móvil. Las
  /// descargas hechas antes de leer por tramos (ver [_pageSize]) se quedaron
  /// en 1000; volver a descargar el libro lo arregla.
  Future<int> missingBlocks(int bookId) async {
    final resp = await _client
        .from('content_blocks')
        .select('id')
        .eq('book_id', bookId)
        .limit(1)
        .count(CountOption.exact)
        .timeout(kNetworkTimeout);
    final missing = resp.count - await _local.countBlocks(bookId);
    return missing > 0 ? missing : 0;
  }

  /// Pone al día el audio de un libro YA descargado con lo que hay en el
  /// servidor, sin volver a bajar el libro.
  ///
  /// El audio se sube a Supabase poco a poco, después de que la gente ya se
  /// haya bajado el texto, y se puede regenerar o quitar (`audiolibro
  /// quitar`). Sin esto, un libro descargado se quedaría para siempre con el
  /// audio que hubiera el día de la descarga.
  ///
  /// Barato: primero pide solo ruta y duración de cada bloque con audio, y
  /// los tiempos de las palabras (`audio_words`, lo que pesa) solo de los
  /// bloques que cambiaron. Un audio regenerado o quitado se borra además de
  /// la caché del móvil, para no seguir sonando con el archivo viejo.
  ///
  /// Devuelve cuántos bloques cambiaron. Sin conexión lanza; quien la llame
  /// decide si importa.
  Future<int> syncAudio(int bookId) async {
    final remote = <int, ({String path, int? ms})>{};
    while (true) {
      final resp = await _client
          .from('content_blocks')
          .select('id,audio_path,audio_ms')
          .eq('book_id', bookId)
          .not('audio_path', 'is', null)
          .order('id', ascending: true)
          .range(remote.length, remote.length + _pageSize - 1)
          .timeout(kNetworkTimeout);
      final rows = resp as List;
      for (final row in rows) {
        final j = row as Map<String, dynamic>;
        remote[j['id'] as int] =
            (path: j['audio_path'] as String, ms: j['audio_ms'] as int?);
      }
      if (rows.length < _pageSize) break;
    }

    final local = await _local.getAudioIndex(bookId);
    final changed = [
      for (final e in remote.entries)
        if (local[e.key] != e.value) e.key,
    ];
    final removed = [
      for (final id in local.keys)
        if (!remote.containsKey(id)) id,
    ];

    final updates = <({int id, String? path, int? ms, String? wordsJson})>[];
    for (var i = 0; i < changed.length; i += _chunkSize) {
      final chunk = changed.sublist(
        i,
        i + _chunkSize > changed.length ? changed.length : i + _chunkSize,
      );
      final resp = await _client
          .from('content_blocks')
          .select('id,audio_path,audio_ms,audio_words')
          .inFilter('id', chunk)
          .timeout(kNetworkTimeout);
      for (final row in resp as List) {
        final j = row as Map<String, dynamic>;
        final words = j['audio_words'];
        updates.add((
          id: j['id'] as int,
          path: j['audio_path'] as String?,
          ms: j['audio_ms'] as int?,
          wordsJson: words is List && words.isNotEmpty ? jsonEncode(words) : null,
        ));
      }
    }
    for (final id in removed) {
      updates.add((id: id, path: null, ms: null, wordsJson: null));
    }
    await _local.updateAudio(updates);

    // El archivo viejo de lo regenerado o quitado ya no vale (la ruta del
    // bucket es la misma, block_<id>.m4a, así que la caché no lo notaría).
    for (final id in [...changed, ...removed]) {
      final old = local[id];
      if (old != null) {
        await BlockAudio.cache.removeFile(BlockAudio.urlFor(old.path));
      }
    }
    return updates.length;
  }

  /// Baja los audios [urls] a su caché, [_imageConcurrency] a la vez.
  Future<void> cacheAudio(
    List<String> urls, {
    void Function(double fraction)? onProgress,
  }) =>
      _cacheAll(urls, BlockAudio.cache, onProgress);

  /// Borra del móvil el audio del libro (el texto sigue descargado).
  Future<void> deleteAudio(int bookId) async {
    for (final path in (await _local.getAudio(bookId)).keys) {
      await BlockAudio.cache.removeFile(BlockAudio.urlFor(path));
    }
  }

  /// Baja [urls] a [cache] en paralelo, con [_fileAttempts] intentos cada uno.
  /// Un archivo que falla igualmente no aborta el resto: se reintentará la
  /// próxima vez, porque se verá como ausente.
  Future<void> _cacheAll(
    List<String> urls,
    BaseCacheManager cache,
    void Function(double fraction)? onProgress,
  ) async {
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
        for (var attempt = 1;; attempt++) {
          try {
            await cache.downloadFile(urls[index]).timeout(_fileTimeout);
            break;
          } catch (_) {
            // Un archivo caído no debe tumbar la descarga entera.
            if (attempt >= _fileAttempts) break;
            await Future<void>.delayed(Duration(seconds: attempt * 2));
          }
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
