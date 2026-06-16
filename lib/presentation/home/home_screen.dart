import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_title.dart';
import '../../data/models/book_model.dart';
import '../../data/repositories/auth_controller.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/cover_store.dart';
import '../../data/repositories/reading_progress_store.dart';
import 'bloc/home_bloc.dart';
import 'bloc/home_event.dart';
import 'bloc/home_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeBloc(BookRepository(Supabase.instance.client))
        ..add(const LoadBooks()),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle(),
        actions: const [_AccountMenu()],
      ),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          switch (state.status) {
            case HomeStatus.initial:
            case HomeStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case HomeStatus.failure:
              return _ErrorView(
                message: state.error ?? 'Algo salió mal.',
                onRetry: () =>
                    context.read<HomeBloc>().add(const LoadBooks()),
              );
            case HomeStatus.success:
              if (state.books.isEmpty) {
                return const Center(child: Text('No hay libros disponibles.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.books.length,
                itemBuilder: (context, index) =>
                    _BookCard(book: state.books[index]),
              );
          }
        },
      ),
    );
  }
}

/// Account menu in the library AppBar: link to the admin panel (admins only)
/// and sign out. After signing out the router redirects to /login.
class _AccountMenu extends StatelessWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context) {
    final auth = AuthController.instance;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (value) async {
        switch (value) {
          case 'admin':
            context.push('/admin');
            break;
          case 'logout':
            await auth.signOut();
            break;
        }
      },
      itemBuilder: (context) => [
        if (auth.isAdmin)
          const PopupMenuItem(
            value: 'admin',
            child: ListTile(
              leading: Icon(Icons.admin_panel_settings_outlined),
              title: Text('Panel de administración'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('Cerrar sesión'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  _BookCard({required this.book});

  final Book book;
  final ReadingProgressStore _progressStore = ReadingProgressStore();

  void _openDetail(BuildContext context) =>
      context.push('/book/${book.id}', extra: book);

  /// Smart-hybrid tap: jump straight into the reader when there's saved
  /// progress (page > 1); otherwise show the detail screen first so the reader
  /// can get to know the book. The (i) button always opens the detail.
  ///
  /// Uses `push` so Home stays at the root of the stack and the system back
  /// button returns to the library.
  Future<void> _onTap(BuildContext context) async {
    final page = await _progressStore.getLastPage(book.id);
    if (!context.mounted) return;
    if (page > 1) {
      context.push('/reader/${book.id}/$page');
    } else {
      _openDetail(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onTap(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BookCover(book: book),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    _ResumeHint(
                      progressStore: _progressStore,
                      bookId: book.id,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Detalle del libro',
              onPressed: () => _openDetail(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows "Continuar en pág. N" when there's saved progress beyond page 1.
class _ResumeHint extends StatelessWidget {
  const _ResumeHint({required this.progressStore, required this.bookId});

  final ReadingProgressStore progressStore;
  final int bookId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: progressStore.getLastPage(bookId),
      builder: (context, snapshot) {
        final page = snapshot.data ?? 1;
        if (page <= 1) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_outline,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Continuar en pág. $page',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    const width = 90.0;
    const height = 130.0;

    // Resolves override → cover_url → first image. Listens to [CoverStore] so a
    // cover changed in the detail screen updates the list on return.
    return ValueListenableBuilder<int>(
      valueListenable: CoverStore.revision,
      builder: (context, _, _) {
        return FutureBuilder<String?>(
          future: BookRepository(Supabase.instance.client).resolveCoverUrl(book),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return SizedBox(
                width: width,
                height: height,
                child: const ColoredBox(color: Color(0x11000000)),
              );
            }
            final url = snapshot.data;
            if (url == null || url.isEmpty) {
              return _PlaceholderCover(book: book, width: width, height: height);
            }
            return CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (context, _) => SizedBox(
                width: width,
                height: height,
                child:
                    const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, _, _) =>
                  _PlaceholderCover(book: book, width: width, height: height),
            );
          },
        );
      },
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
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
