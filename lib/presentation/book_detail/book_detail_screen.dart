import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../data/local/app_database.dart';
import '../../data/local/local_book_store.dart';
import '../../data/models/book_model.dart';
import '../../data/repositories/book_download_service.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/cover_store.dart';
import '../../data/repositories/download_manager.dart';
import '../../data/repositories/reading_progress_store.dart';

/// Book detail: cover, title, author, metadata and a "read / continue" button.
/// Reached from the home list before opening the reader.
class BookDetailScreen extends StatefulWidget {
  const BookDetailScreen({super.key, required this.bookId, this.book});

  final int bookId;

  /// Optional book passed from the list to avoid a refetch. When null the
  /// screen fetches it by id (deep-link friendly).
  final Book? book;

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final ReadingProgressStore _progressStore = ReadingProgressStore();
  late final Future<Book?> _bookFuture;

  @override
  void initState() {
    super.initState();
    _bookFuture = widget.book != null
        ? Future.value(widget.book)
        : BookRepository(Supabase.instance.client).getBookById(widget.bookId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      body: FutureBuilder<Book?>(
        future: _bookFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final book = snapshot.data;
          if (book == null) {
            return const Center(child: Text('No se encontró el libro.'));
          }
          return _DetailBody(book: book, progressStore: _progressStore);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.book, required this.progressStore});

  final Book book;
  final ReadingProgressStore progressStore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Cover(book: book),
          const SizedBox(height: 24),
          Text(
            book.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (book.author != null && book.author!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              book.author!,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (book.totalPages != null)
                _MetaChip(
                  icon: Icons.menu_book_outlined,
                  label: '${book.totalPages} páginas',
                ),
              if (book.language != null && book.language!.isNotEmpty)
                _MetaChip(
                  icon: Icons.translate,
                  label: book.language!.toUpperCase(),
                ),
            ],
          ),
          const SizedBox(height: 32),
          FutureBuilder<int>(
            future: progressStore.getLastPage(book.id),
            builder: (context, snapshot) {
              final page = snapshot.data ?? 1;
              final resuming = page > 1;
              return SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      context.pushReplacement('/reader/${book.id}/$page'),
                  icon: Icon(resuming ? Icons.play_arrow : Icons.menu_book),
                  label: Text(
                    resuming ? 'Continuar en pág. $page' : 'Comenzar a leer',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _OfflineButton(book: book),
        ],
      ),
    );
  }
}

/// Downloads / removes the book for offline reading, with progress.
class _OfflineButton extends StatefulWidget {
  const _OfflineButton({required this.book});

  final Book book;

  @override
  State<_OfflineButton> createState() => _OfflineButtonState();
}

enum _OfflineStatus { checking, available, downloaded }

class _OfflineButtonState extends State<_OfflineButton> {
  final LocalBookStore _local = LocalBookStore(AppDatabase.instance);
  late final BookDownloadService _downloader = BookDownloadService(
    Supabase.instance.client,
    _local,
  );
  final DownloadManager _manager = DownloadManager.instance;

  _OfflineStatus _status = _OfflineStatus.checking;

  /// Imágenes del libro que no están en la caché. Mientras haya alguna, el
  /// libro se lee bien pero se ve con huecos sin conexión, así que se dice y
  /// se ofrece completarlo.
  int _missingImages = 0;

  /// Duración del audio en inglés del libro, y la parte que aún no está en el
  /// móvil. Ambos 0 si el libro no tiene audio (o en web, que lo reproduce
  /// directamente desde la URL).
  int _audioTotalMs = 0;
  int _audioMissingMs = 0;

  /// Bloques que el servidor tiene y esta descarga no (descargas viejas,
  /// cortadas en 1000). Se ofrece actualizar la descarga.
  int _missingBlocks = 0;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onManagerChanged);
    _refresh();
    _checkServer();
  }

  /// Una vez por visita, y solo si hay red: trae el audio que se haya subido
  /// (o quitado) desde la descarga, y mira si a la descarga le faltan bloques.
  /// Sin conexión no pasa nada: se queda con lo que hay en el móvil.
  Future<void> _checkServer() async {
    if (!await _local.isDownloaded(widget.book.id)) return;
    try {
      final missingBlocks = await _downloader.missingBlocks(widget.book.id);
      final changed = await _downloader.syncAudio(widget.book.id);
      if (!mounted) return;
      setState(() => _missingBlocks = missingBlocks);
      if (changed > 0) await _refresh();
    } catch (_) {
      // Sin red o servidor caído: el libro descargado sigue sirviendo.
    }
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerChanged);
    super.dispose();
  }

  /// La descarga vive en [DownloadManager], no aquí: esta pantalla solo se
  /// vuelve a pintar cuando aquello avanza, y al terminar recuenta.
  void _onManagerChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_manager.isRunning(widget.book.id)) _refresh();
  }

  Future<void> _refresh() async {
    final downloaded = await _local.isDownloaded(widget.book.id);
    final missing = downloaded
        ? await _downloader.missingImages(widget.book.id)
        : const [];
    final audio = downloaded && !kIsWeb
        ? await _downloader.audioStatus(widget.book.id)
        : null;
    if (!mounted) return;
    setState(() {
      _status = downloaded
          ? _OfflineStatus.downloaded
          : _OfflineStatus.available;
      _missingImages = missing.length;
      _audioTotalMs = audio?.totalMs ?? 0;
      _audioMissingMs = audio?.missingMs ?? 0;
    });
  }

  Future<void> _downloadAudio() async {
    await _manager.downloadAudio(
      widget.book.id,
      _downloader,
      title: widget.book.title,
    );
    if (!mounted) return;
    final error = _manager.errorOf(widget.book.id);
    _manager.clearError(widget.book.id);
    _toast(switch (error) {
      null => 'Audio descargado',
      DownloadCancelled() => 'Descarga cancelada',
      _ => 'No se pudo bajar el audio: $error',
    });
  }

  Future<void> _deleteAudio() async {
    await _downloader.deleteAudio(widget.book.id);
    await _refresh();
    if (mounted) _toast('Audio eliminado del dispositivo');
  }

  /// AAC mono a 32 kbps ≈ 4 KB por segundo de voz.
  static String _audioSize(int ms) {
    final mb = ms / 1000 * 4 / 1024;
    return mb < 1 ? '< 1 MB' : '~${mb.round()} MB';
  }

  static String _audioLength(int ms) {
    final minutes = (ms / 60000).round();
    return minutes < 60
        ? '$minutes min'
        : '${minutes ~/ 60} h ${minutes % 60} min';
  }

  Future<void> _download() async {
    await _manager.start(widget.book.id, _downloader, title: widget.book.title);
    if (!mounted) return;
    final error = _manager.errorOf(widget.book.id);
    _manager.clearError(widget.book.id);
    if (error != null) {
      _toast(
        error is DownloadCancelled
            ? 'Descarga cancelada'
            : 'No se pudo descargar: $error',
      );
      return;
    }
    setState(() => _missingBlocks = 0);
    // Antes decía «Descargado» aunque alguna imagen no hubiera bajado, y no
    // se notaba hasta leer sin conexión y encontrar el hueco.
    final missing = await _downloader.missingImages(widget.book.id);
    if (!mounted) return;
    _toast(
      missing.isEmpty
          ? 'Descargado para leer sin conexión'
          : 'Descargado, pero ${_imagesText(missing.length)} no se '
                '${missing.length == 1 ? 'pudo' : 'pudieron'} bajar. '
                'Toca «Completar descarga» con conexión.',
    );
  }

  Future<void> _completeImages() async {
    await _manager.completeImages(
      widget.book.id,
      _downloader,
      title: widget.book.title,
    );
    if (!mounted) return;
    final error = _manager.errorOf(widget.book.id);
    _manager.clearError(widget.book.id);
    if (error != null) {
      _toast(
        error is DownloadCancelled
            ? 'Descarga cancelada'
            : 'No se pudieron bajar las imágenes: $error',
      );
      return;
    }
    final missing = await _downloader.missingImages(widget.book.id);
    if (!mounted) return;
    _toast(
      missing.isEmpty
          ? 'Imágenes completas: disponible sin conexión'
          : 'Aún ${missing.length == 1 ? 'falta' : 'faltan'} '
                '${_imagesText(missing.length)}. Revisa la conexión y reintenta.',
    );
  }

  static String _imagesText(int n) => n == 1 ? '1 imagen' : '$n imágenes';

  Future<void> _delete() async {
    // Imágenes y audio primero: salen de la base local, y sin ella ya no se
    // sabría qué archivos eran de este libro (se quedarían ocupando sitio).
    try {
      await _downloader.deleteImages(widget.book.id);
      await _downloader.deleteAudio(widget.book.id);
    } catch (_) {
      // Que no impida eliminar el libro.
    }
    await _local.deleteBook(widget.book.id);
    if (!mounted) return;
    setState(() {
      _status = _OfflineStatus.available;
      _missingImages = 0;
      _missingBlocks = 0;
    });
    _toast('Descarga eliminada');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Una descarga en curso manda sobre todo lo demás: puede haber empezado en
    // esta pantalla o haber seguido viva mientras el usuario andaba por otra.
    final progress = _manager.progressOf(widget.book.id);
    if (progress != null) {
      final pct = (progress * 100).clamp(0, 100).toStringAsFixed(0);
      return Column(
        children: [
          LinearProgressIndicator(value: progress == 0 ? null : progress),
          const SizedBox(height: 8),
          Text(
            'Descargando… $pct%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            _manager.canCancel
                ? 'Puedes cerrar la app: la descarga sigue y te avisa al '
                      'terminar.'
                : 'Puedes salir de aquí: la descarga sigue.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (_manager.canCancel)
            TextButton.icon(
              onPressed: () => _manager.cancel(widget.book.id),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Cancelar'),
            ),
        ],
      );
    }

    switch (_status) {
      case _OfflineStatus.checking:
        return const SizedBox(height: 40);

      case _OfflineStatus.downloaded:
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _missingImages == 0 ? Icons.offline_pin : Icons.cloud_off,
                  size: 18,
                  color: _missingImages == 0 ? scheme.primary : scheme.error,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _missingImages == 0
                        ? 'Disponible sin conexión'
                        : 'Falta${_missingImages == 1 ? '' : 'n'} '
                              '$_missingImages imagen'
                              '${_missingImages == 1 ? '' : 'es'}',
                    style: TextStyle(
                      color: _missingImages == 0
                          ? scheme.primary
                          : scheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Eliminar'),
                ),
              ],
            ),
            if (_missingBlocks > 0)
              TextButton.icon(
                onPressed: _download,
                icon: const Icon(Icons.sync, size: 18),
                label: Text(
                  'Actualizar descarga (faltan $_missingBlocks bloques)',
                ),
              ),
            if (_missingImages > 0)
              TextButton.icon(
                onPressed: _completeImages,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Completar descarga'),
              ),
            if (_audioTotalMs > 0) ...[
              const SizedBox(height: 4),
              if (_audioMissingMs == 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.headphones, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Audio en inglés sin conexión '
                        '(${_audioLength(_audioTotalMs)})',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: _deleteAudio,
                      child: const Text('Quitar'),
                    ),
                  ],
                )
              else
                TextButton.icon(
                  onPressed: _downloadAudio,
                  icon: const Icon(Icons.headphones, size: 18),
                  label: Text(
                    'Descargar audio en inglés '
                    '(${_audioSize(_audioMissingMs)})',
                  ),
                ),
            ],
          ],
        );

      case _OfflineStatus.available:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _download,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Descargar para leer sin conexión'),
          ),
        );
    }
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.book});

  final Book book;

  static const double _width = 160.0;
  static const double _height = 230.0;

  Future<void> _changeCover(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = BookRepository(Supabase.instance.client);
    final images = await repo.getBookImageUrls(book.id);
    if (!context.mounted) return;
    if (images.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Este libro no tiene imágenes para usar como portada.',
            ),
          ),
        );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CoverPickerSheet(bookId: book.id, images: images),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Re-resolves when the override changes so the cover updates in place.
    final cover = ValueListenableBuilder<int>(
      valueListenable: CoverStore.revision,
      builder: (context, _, _) {
        return FutureBuilder<String?>(
          future: BookRepository(
            Supabase.instance.client,
          ).resolveCoverUrl(book),
          builder: (context, snapshot) {
            final url = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                width: _width,
                height: _height,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (url == null || url.isEmpty) {
              return _PlaceholderCover(
                book: book,
                width: _width,
                height: _height,
              );
            }
            return CachedNetworkImage(
              imageUrl: url,
              width: _width,
              height: _height,
              fit: BoxFit.cover,
              placeholder: (context, _) => const SizedBox(
                width: _width,
                height: _height,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, _, _) =>
                  _PlaceholderCover(book: book, width: _width, height: _height),
            );
          },
        );
      },
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Material(elevation: 6, child: cover),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _changeCover(context),
          icon: const Icon(Icons.image_outlined, size: 18),
          label: const Text('Cambiar portada'),
        ),
      ],
    );
  }
}

/// Bottom sheet that lets the reader pick any of the book's images as its cover,
/// or reset to the default (first image). Selection is saved per user in
/// [CoverStore] and every cover widget refreshes via [CoverStore.revision].
class _CoverPickerSheet extends StatelessWidget {
  const _CoverPickerSheet({required this.bookId, required this.images});

  final int bookId;
  final List<String> images;

  @override
  Widget build(BuildContext context) {
    final store = CoverStore();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Elegir portada',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await store.clearOverride(bookId);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Restablecer'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.7,
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final url = images[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      await store.setOverride(bookId, url);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (context, _) => const ColoredBox(
                          color: Color(0x11000000),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, _, _) => const ColoredBox(
                          color: Color(0x11000000),
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover({
    required this.book,
    required this.width,
    required this.height,
  });

  final Book book;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final initials = book.title.trim().isEmpty
        ? '?'
        : book.title
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
              .join();

    return Container(
      width: width,
      height: height,
      color: AppTheme.accent,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: scheme.onSurface)),
        ],
      ),
    );
  }
}
