import 'package:cached_network_image/cached_network_image.dart';
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
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (book.author != null && book.author!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              book.author!,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.secondary),
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

enum _OfflineStatus { checking, available, downloading, downloaded }

class _OfflineButtonState extends State<_OfflineButton> {
  final LocalBookStore _local = LocalBookStore(AppDatabase.instance);
  late final BookDownloadService _downloader =
      BookDownloadService(Supabase.instance.client, _local);

  _OfflineStatus _status = _OfflineStatus.checking;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final downloaded = await _local.isDownloaded(widget.book.id);
    if (!mounted) return;
    setState(() => _status =
        downloaded ? _OfflineStatus.downloaded : _OfflineStatus.available);
  }

  Future<void> _download() async {
    setState(() {
      _status = _OfflineStatus.downloading;
      _progress = 0;
    });
    try {
      await _downloader.download(
        widget.book.id,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _status = _OfflineStatus.downloaded);
      _toast('Descargado para leer sin conexión');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = _OfflineStatus.available);
      _toast('No se pudo descargar: $e');
    }
  }

  Future<void> _delete() async {
    await _local.deleteBook(widget.book.id);
    if (!mounted) return;
    setState(() => _status = _OfflineStatus.available);
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

    switch (_status) {
      case _OfflineStatus.checking:
        return const SizedBox(height: 40);

      case _OfflineStatus.downloading:
        final pct = (_progress * 100).clamp(0, 100).toStringAsFixed(0);
        return Column(
          children: [
            LinearProgressIndicator(value: _progress == 0 ? null : _progress),
            const SizedBox(height: 8),
            Text('Descargando… $pct%',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        );

      case _OfflineStatus.downloaded:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.offline_pin, size: 18, color: scheme.primary),
            const SizedBox(width: 6),
            Text(
              'Disponible sin conexión',
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Eliminar'),
            ),
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
        ..showSnackBar(const SnackBar(
          content: Text('Este libro no tiene imágenes para usar como portada.'),
        ));
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
          future: BookRepository(Supabase.instance.client).resolveCoverUrl(book),
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
                  book: book, width: _width, height: _height);
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
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
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
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
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
