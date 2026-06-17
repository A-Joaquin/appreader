import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings/reader_settings.dart';
import '../../core/widgets/brand_title.dart';
import '../../data/models/book_model.dart';
import '../../data/models/content_block_model.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/reader_repository.dart';
import '../../data/repositories/reading_progress_store.dart';
import 'bloc/reader_bloc.dart';
import 'bloc/reader_event.dart';
import 'bloc/reader_state.dart';
import 'widgets/code_block_widget.dart';
import 'widgets/image_block_widget.dart';
import 'widgets/text_block_widget.dart';
import 'widgets/translation_bar.dart';

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    super.key,
    required this.bookId,
    required this.pageNumber,
  });

  final int bookId;
  final int pageNumber;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReaderBloc(
        bookId: bookId,
        readerRepository: ReaderRepository(Supabase.instance.client),
        bookRepository: BookRepository(Supabase.instance.client),
      )..add(LoadPage(bookId: bookId, pageNumber: pageNumber)),
      child: const _ReaderView(),
    );
  }
}

class _ReaderView extends StatefulWidget {
  const _ReaderView();

  @override
  State<_ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<_ReaderView>
    with SingleTickerProviderStateMixin {
  final ItemScrollController _bookScrollController = ItemScrollController();

  /// Drives the page-turn curl when the page changes. The bloc holds one page
  /// at a time: on a page change we snapshot the OUTGOING page to an image and
  /// paint it curling away over the live incoming page (see [_PageCurlPainter]).
  late final AnimationController _pageAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1, // start settled so the first frame isn't mid-transition
  );

  /// Snapshot of the page we just left, painted curling away. Null when no turn
  /// is in flight. Disposed when the animation finishes.
  ui.Image? _curlImage;

  /// True when the in-flight turn is forward (peel from the right edge towards
  /// the spine); false peels from the left (going back).
  bool _curlForward = true;

  /// Device pixel ratio captured with the snapshot, so the painter can map the
  /// image's pixels back to logical coordinates.
  double _curlDpr = 1;

  /// Wraps the live page content so we can snapshot it on a page change.
  final GlobalKey _pageBoundaryKey = GlobalKey();

  /// +1 = moving forward, -1 = backward. Computed from the page delta in the
  /// listener (works for swipes, buttons, the jump dialog — any source).
  int _navDirection = 1;

  /// The page currently shown on screen, used to detect real page changes and
  /// their direction.
  int _renderedPage = 0;

  /// Min fling speed (px/s) on a horizontal drag to count as a page swipe.
  static const double _swipeVelocity = 250;

  /// Marks the translation bar so we can measure its rendered height. The bar
  /// is a top overlay; we reserve a PERMANENT blank gap at the top of the page
  /// the size of the bar so it never covers the first paragraphs.
  final GlobalKey _barKey = GlobalKey();

  /// High-water mark of the bar's height: the tallest it has been (e.g. once the
  /// word pill has shown). We reserve this much blank space at the top of the
  /// page permanently — the text pushes down when the bar/pill first appears and
  /// never jumps back up when the bar is dismissed.
  double _reservedTop = 0;

  /// Re-measures the bar after layout and grows the reserved top gap to match
  /// its tallest seen height. It never shrinks, so dismissing the bar leaves the
  /// gap in place (no upward jump).
  void _syncBarHeight() {
    final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    final height = box?.size.height ?? 0;
    if (height > _reservedTop && mounted) {
      setState(() => _reservedTop = height);
    }
  }

  /// Turns a horizontal fling into page navigation: swipe left → next page,
  /// swipe right → previous page. Respects the page bounds so we don't run off
  /// either end. The slide animation itself is triggered from the listener once
  /// the new page lands.
  void _onHorizontalSwipe(BuildContext context, ReaderState state, double velocity) {
    if (velocity.abs() < _swipeVelocity) return;
    final total = state.totalPages;
    if (velocity < 0) {
      // Finger moved left → advance.
      final canGoNext = total == null || state.currentPage < total;
      if (canGoNext) {
        context.read<ReaderBloc>().add(NavigateToPage(state.currentPage + 1));
      }
    } else {
      // Finger moved right → go back.
      if (state.currentPage > 1) {
        context.read<ReaderBloc>().add(NavigateToPage(state.currentPage - 1));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Drop the curl snapshot once the turn finishes so the live page shows
    // through again (and we free the GPU image).
    _pageAnim.addStatusListener((status) {
      if (status == AnimationStatus.completed && _curlImage != null) {
        setState(() {
          _curlImage?.dispose();
          _curlImage = null;
        });
      }
    });
  }

  /// Grabs the currently painted page as a GPU image so it can be painted
  /// curling away. Synchronous (no async gap → no flicker); returns null if the
  /// boundary isn't ready yet (then we just skip the curl for that turn).
  ui.Image? _capturePage() {
    final boundary = _pageBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize) return null;
    return boundary.toImageSync(pixelRatio: _curlDpr);
  }

  /// Kicks off a page-turn curl: snapshot the page we're leaving and animate it
  /// peeling away over the freshly-loaded page underneath.
  void _startCurl(int previousPage, int newPage) {
    _navDirection = newPage > previousPage ? 1 : -1;
    final snapshot = _capturePage();
    if (_bookScrollController.isAttached) {
      _bookScrollController.jumpTo(index: 0);
    }
    _curlImage?.dispose();
    _curlImage = snapshot;
    _curlForward = _navDirection > 0;
    if (snapshot == null) {
      // Couldn't snapshot → skip the effect, just show the new page.
      _pageAnim.value = 1;
    } else {
      _pageAnim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _curlImage?.dispose();
    _pageAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Capture the pixel ratio for snapshotting the page on the next turn.
    _curlDpr = MediaQuery.devicePixelRatioOf(context);
    return Scaffold(
      drawer: _LibraryDrawer(currentBookId: context.read<ReaderBloc>().bookId),
      appBar: AppBar(
        title: const BrandTitle(),
        actions: const [_ReaderSettingsActions()],
      ),
      body: BlocConsumer<ReaderBloc, ReaderState>(
        // Only react to actual page changes. Without this guard the listener
        // fires on every state emission — including word taps — and would
        // yank the page back to the top each time a word is tapped.
        listenWhen: (previous, current) =>
            previous.currentPage != current.currentPage ||
            previous.isLoading != current.isLoading,
        listener: (context, state) {
          if (!state.isLoading && state.error == null) {
            if (state.currentPage != _renderedPage) {
              // Snapshot the outgoing page and curl it away over the new one.
              final previous = _renderedPage;
              _renderedPage = state.currentPage;
              _startCurl(previous, state.currentPage);
            }
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null) {
            return _ErrorView(
              message: state.error!,
              onRetry: () => context.read<ReaderBloc>().add(
                    LoadPage(
                      bookId: context.read<ReaderBloc>().bookId,
                      pageNumber: state.currentPage,
                    ),
                  ),
            );
          }

          // Re-measure the overlay bar after each layout so the reserved top
          // space below tracks its real height (it grows with the word pill).
          WidgetsBinding.instance.addPostFrameCallback((_) => _syncBarHeight());

          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // Live page content, wrapped so we can snapshot it for the
                    // curl when turning. The incoming page sits here underneath
                    // the curling snapshot of the page we left. The opaque
                    // background is essential: it makes the snapshot fully cover
                    // the new page so the two pages' text never show through each
                    // other — the new page is revealed only as the sheet curls.
                    RepaintBoundary(
                      key: _pageBoundaryKey,
                      child: ColoredBox(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => context
                              .read<ReaderBloc>()
                              .add(const HideTranslation()),
                          // Horizontal fling turns the page; vertical scrolling
                          // stays with the list, so the two don't fight.
                          onHorizontalDragEnd: (details) => _onHorizontalSwipe(
                            context,
                            state,
                            details.primaryVelocity ?? 0,
                          ),
                          child: ScrollablePositionedList.builder(
                          itemScrollController: _bookScrollController,
                          itemCount: state.blocks.length,
                          // PERMANENT top gap the size of the compact bar (and
                          // its word-pill section): the first paragraphs always
                          // start below where the bar appears, so selecting a
                          // word never gets covered AND dismissing the bar never
                          // jumps the text back up. The big BOTTOM gap is also
                          // intentional blank space: it lets the reader scroll
                          // the last lines up to the top so they sit beside the
                          // compact bar comfortably, and signals the page's end.
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16 + _reservedTop,
                            16,
                            MediaQuery.sizeOf(context).height * 0.6,
                          ),
                          itemBuilder: (context, index) =>
                              _buildBlock(context, state, state.blocks[index]),
                          ),
                        ),
                      ),
                    ),
                    // The page we just left, curling away to reveal the one
                    // above. Only present while a turn is in flight.
                    if (_curlImage != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _PageCurlPainter(
                              image: _curlImage!,
                              animation: _pageAnim,
                              forward: _curlForward,
                              dpr: _curlDpr,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        ignoring: !state.isBarVisible,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          offset: state.isBarVisible
                              ? Offset.zero
                              : const Offset(0, -1.5),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: state.isBarVisible ? 1 : 0,
                            child: TranslationBar(
                              key: _barKey,
                              fragments: state.pageFragments,
                              targetIndex: state.targetFragment,
                              direction:
                                  ReaderSettingsScope.of(context).direction,
                              highlightStart: state.highlightStart,
                              highlightEnd: state.highlightEnd,
                              bodyWord: state.tappedBodyWord,
                              barWord: state.tappedBarWord,
                              onClose: () => context
                                  .read<ReaderBloc>()
                                  .add(const HideTranslation()),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _NavigationBar(state: state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBlock(BuildContext context, ReaderState state, ContentBlock block) {
    switch (block.blockType) {
      case 'image':
        return ImageBlockWidget(block: block);
      case 'code_snippet':
        return CodeBlockWidget(block: block);
      default:
        final direction = ReaderSettingsScope.of(context).direction;
        return TextBlockWidget(
          block: block,
          fragments: state.pageFragments,
          direction: direction,
          selectedBlockId: state.selectedBlockId,
          selectedFragmentOrder: state.selectedFragmentOrder,
          selectedCharOffset: state.selectedCharOffset,
          onWordTap: (fragmentOrder, charOffset) {
            // The top gap is reserved permanently (see [_reservedTop]), so the
            // bar always has room and tapping a word never shifts the page.
            context.read<ReaderBloc>().add(
                  WordTapped(
                    blockId: block.id,
                    fragmentOrder: fragmentOrder,
                    charOffset: charOffset,
                    direction: direction,
                  ),
                );
          },
        );
    }
  }
}

/// Paints a snapshot of the page being left as a real sheet of paper curling
/// away to reveal the page underneath. The paper wraps around a vertical
/// cylinder whose contact line sweeps across the page; texture columns past the
/// line are bent onto the cylinder (compressed horizontally) and shaded so the
/// crest catches light and the underside darkens — the look of a turning page,
/// not a flat rotating card.
class _PageCurlPainter extends CustomPainter {
  _PageCurlPainter({
    required this.image,
    required this.animation,
    required this.forward,
    required this.dpr,
  }) : super(repaint: animation);

  final ui.Image image;
  final Animation<double> animation;

  /// Forward peels from the right edge towards the spine (left); backward peels
  /// from the left towards the right.
  final bool forward;

  /// Pixel ratio the [image] was captured at, to map logical x/y to image px.
  final double dpr;

  static const int _cols = 48; // mesh resolution across the page

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeInOut.transform(animation.value.clamp(0.0, 1.0));
    if (t <= 0) {
      // Page not lifted yet: just paint the snapshot flat.
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Offset.zero & size,
        Paint(),
      );
      return;
    }
    if (t >= 1) return; // fully turned → live page shows through

    final w = size.width;
    final h = size.height;
    final r = w * 0.13; // curl radius: smaller = thinner, tighter paper
    // Contact line sweeps fully across plus the cylinder's half-circumference so
    // the sheet leaves completely by t = 1.
    final travel = w + math.pi * r;
    final curlPos = forward ? w - t * travel : t * travel;

    // Soft shadow the lifted sheet casts on the revealed page, just ahead of the
    // curl's crest.
    final crest = forward ? curlPos + r : curlPos - r;
    const shadowW = 26.0;
    final shadowRect = forward
        ? Rect.fromLTWH(crest, 0, shadowW, h)
        : Rect.fromLTWH(crest - shadowW, 0, shadowW, h);
    final shadowPaint = Paint()
      ..shader = LinearGradient(
        begin: forward ? Alignment.centerLeft : Alignment.centerRight,
        end: forward ? Alignment.centerRight : Alignment.centerLeft,
        colors: [Colors.black.withValues(alpha: 0.22), Colors.transparent],
      ).createShader(shadowRect);
    canvas.drawRect(shadowRect, shadowPaint);

    // Build a 2-row mesh strip across the page, bending the curled columns.
    final positions = <Offset>[];
    final uvs = <Offset>[];
    final colors = <Color>[];
    for (var i = 0; i <= _cols; i++) {
      final x = i / _cols * w;
      var theta = (forward ? (x - curlPos) : (curlPos - x)) / r;
      double sx;
      double brightness;
      if (theta <= 0) {
        // Flat part still lying on the page.
        sx = x;
        brightness = 1;
      } else {
        if (theta > 2 * math.pi) theta = 2 * math.pi;
        final off = r * math.sin(theta);
        sx = forward ? curlPos + off : curlPos - off;
        // Lambert-ish shading: lit at the crest, darkest on the vertical edge.
        final shade = (math.cos(theta) + 1) / 2; // 1 flat .. 0 facing away
        brightness = 0.45 + 0.55 * shade;
      }
      final color = Color.from(
        alpha: 1,
        red: brightness,
        green: brightness,
        blue: brightness,
      );
      positions.add(Offset(sx, 0));
      positions.add(Offset(sx, h));
      uvs.add(Offset(x * dpr, 0));
      uvs.add(Offset(x * dpr, h * dpr));
      colors.add(color);
      colors.add(color);
    }

    final vertices = ui.Vertices(
      VertexMode.triangleStrip,
      positions,
      textureCoordinates: uvs,
      colors: colors,
    );
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = ui.ImageShader(
        image,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.identity().storage,
      );
    // Modulate the sampled paper texture by the per-vertex shading colours.
    canvas.drawVertices(vertices, BlendMode.modulate, paint);
  }

  @override
  bool shouldRepaint(_PageCurlPainter old) =>
      old.image != image || old.forward != forward || old.dpr != dpr;
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({required this.state});

  final ReaderState state;

  @override
  Widget build(BuildContext context) {
    final canGoPrevious = state.currentPage > 1;
    final totalPages = state.totalPages;
    final canGoNext =
        totalPages == null || state.currentPage < totalPages;
    final scheme = Theme.of(context).colorScheme;

    final progress = (totalPages != null && totalPages > 0)
        ? (state.currentPage / totalPages).clamp(0.0, 1.0)
        : null;

    final label = totalPages != null
        ? 'Página ${state.currentPage} de $totalPages'
        : 'Página ${state.currentPage}';

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
              color: scheme.primary,
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: canGoPrevious
                        ? () => context
                            .read<ReaderBloc>()
                            .add(NavigateToPage(state.currentPage - 1))
                        : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Anterior'),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: totalPages != null && totalPages > 1
                        ? () => _showPageJumpDialog(context, totalPages)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Text(label),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: canGoNext
                        ? () => context
                            .read<ReaderBloc>()
                            .add(NavigateToPage(state.currentPage + 1))
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Siguiente'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPageJumpDialog(BuildContext context, int totalPages) {
    final bloc = context.read<ReaderBloc>();
    showDialog<void>(
      context: context,
      builder: (_) => _PageJumpDialog(
        currentPage: state.currentPage,
        totalPages: totalPages,
        onJump: (page) => bloc.add(NavigateToPage(page)),
      ),
    );
  }
}

/// Slider dialog to jump directly to any page.
class _PageJumpDialog extends StatefulWidget {
  const _PageJumpDialog({
    required this.currentPage,
    required this.totalPages,
    required this.onJump,
  });

  final int currentPage;
  final int totalPages;
  final void Function(int page) onJump;

  @override
  State<_PageJumpDialog> createState() => _PageJumpDialogState();
}

class _PageJumpDialogState extends State<_PageJumpDialog> {
  late double _selected = widget.currentPage.toDouble();

  @override
  Widget build(BuildContext context) {
    final page = _selected.round();
    return AlertDialog(
      title: const Text('Ir a la página'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$page de ${widget.totalPages}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Slider(
            value: _selected,
            min: 1,
            max: widget.totalPages.toDouble(),
            divisions: widget.totalPages > 1 ? widget.totalPages - 1 : null,
            label: '$page',
            onChanged: (value) => setState(() => _selected = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (page != widget.currentPage) widget.onJump(page);
            Navigator.of(context).pop();
          },
          child: const Text('Ir'),
        ),
      ],
    );
  }
}

/// Side drawer listing all books so the reader can switch without leaving the
/// reader. The current book is marked; tapping another jumps straight to its
/// last-read page.
class _LibraryDrawer extends StatefulWidget {
  const _LibraryDrawer({required this.currentBookId});

  final int currentBookId;

  @override
  State<_LibraryDrawer> createState() => _LibraryDrawerState();
}

class _LibraryDrawerState extends State<_LibraryDrawer> {
  final ReadingProgressStore _progressStore = ReadingProgressStore();
  late final Future<List<Book>> _booksFuture =
      BookRepository(Supabase.instance.client).getBooks();

  Future<void> _openBook(BuildContext context, Book book) async {
    if (book.id == widget.currentBookId) {
      Navigator.of(context).pop(); // just close the drawer
      return;
    }
    final page = await _progressStore.getLastPage(book.id);
    if (!context.mounted) return;
    Navigator.of(context).pop(); // close drawer
    // Replace the current reader so the stack stays [Home, Reader] and the
    // back button keeps returning to the library.
    context.pushReplacement('/reader/${book.id}/$page');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Biblioteca',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Todos los libros'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/');
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<Book>>(
                future: _booksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final books = snapshot.data ?? const <Book>[];
                  if (books.isEmpty) {
                    return const Center(child: Text('No hay libros.'));
                  }
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      final isCurrent = book.id == widget.currentBookId;
                      return ListTile(
                        selected: isCurrent,
                        selectedTileColor:
                            scheme.primary.withValues(alpha: 0.08),
                        leading: Icon(
                          isCurrent
                              ? Icons.menu_book
                              : Icons.book_outlined,
                          color: isCurrent ? scheme.primary : null,
                        ),
                        title: Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                        subtitle: book.author != null && book.author!.isNotEmpty
                            ? Text(book.author!,
                                maxLines: 1, overflow: TextOverflow.ellipsis)
                            : null,
                        trailing: isCurrent
                            ? Icon(Icons.check, color: scheme.primary, size: 18)
                            : null,
                        onTap: () => _openBook(context, book),
                      );
                    },
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

/// AppBar controls: font size (A-/A+) plus a single compact, interactive
/// selector that swaps between the theme and language controls (see
/// [_ControlSelector]).
class _ReaderSettingsActions extends StatelessWidget {
  const _ReaderSettingsActions();

  @override
  Widget build(BuildContext context) {
    final settings = ReaderSettingsScope.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.text_decrease, size: 22),
          tooltip: 'Reducir texto',
          visualDensity: VisualDensity.compact,
          onPressed: settings.canDecreaseFont ? settings.decreaseFont : null,
        ),
        IconButton(
          icon: const Icon(Icons.text_increase, size: 22),
          tooltip: 'Aumentar texto',
          visualDensity: VisualDensity.compact,
          onPressed: settings.canIncreaseFont ? settings.increaseFont : null,
        ),
        const _ControlSelector(),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Which control the [_ControlSelector] is currently showing.
enum _Control { theme, language }

/// Compact single-slot control for the AppBar that avoids crowding: only ONE
/// icon (theme OR language) is shown at a time. A short **tap** runs that
/// control's action; a **long-press** swaps which control is shown. No arrow.
class _ControlSelector extends StatefulWidget {
  const _ControlSelector();

  @override
  State<_ControlSelector> createState() => _ControlSelectorState();
}

class _ControlSelectorState extends State<_ControlSelector> {
  _Control _selected = _Control.theme;

  void _swapControl() {
    HapticFeedback.selectionClick();
    setState(() {
      _selected =
          _selected == _Control.theme ? _Control.language : _Control.theme;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ReaderSettingsScope.of(context);
    final isTheme = _selected == _Control.theme;

    final String tooltip;
    final VoidCallback onTap;
    final Widget child;

    if (isTheme) {
      final icon = switch (settings.theme) {
        ReaderTheme.system => Icons.brightness_auto_outlined,
        ReaderTheme.light => Icons.light_mode_outlined,
        ReaderTheme.sepia => Icons.local_cafe_outlined,
        ReaderTheme.dark => Icons.dark_mode_outlined,
      };
      final mode = switch (settings.theme) {
        ReaderTheme.system => 'automático',
        ReaderTheme.light => 'claro',
        ReaderTheme.sepia => 'sepia',
        ReaderTheme.dark => 'oscuro',
      };
      tooltip = 'Tema: $mode · toca para cambiar · mantén para idioma';
      onTap = settings.cycleTheme;
      child = Icon(icon, size: 22);
    } else {
      final isEnToEs = settings.direction == TranslationDirection.enToEs;
      tooltip = isEnToEs
          ? 'Leyendo en inglés · toca para español · mantén para tema'
          : 'Leyendo en español · toca para inglés · mantén para tema';
      // Flip direction; hide the bar first (current offsets belong to the
      // other language).
      onTap = () {
        settings.toggleDirection();
        context.read<ReaderBloc>().add(const HideTranslation());
      };
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.translate, size: 20),
          const SizedBox(width: 3),
          Text(
            isEnToEs ? 'EN' : 'ES',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      );
    }

    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        onLongPress: _swapControl,
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: child,
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
