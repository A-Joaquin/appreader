import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/settings/reader_settings.dart';
import '../../../data/models/block_fragment_model.dart';
import '../../../data/models/content_block_model.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../data/repositories/reader_repository.dart';
import '../../../data/repositories/reading_progress_store.dart';
import 'reader_event.dart';
import 'reader_state.dart';

/// Blocks + fragments of a single page, kept in memory so revisiting the page
/// (e.g. paging back and forth) doesn't hit the network again.
class _CachedPage {
  const _CachedPage(this.blocks, this.fragments);

  final List<ContentBlock> blocks;
  final List<BlockFragment> fragments;
}

class ReaderBloc extends Bloc<ReaderEvent, ReaderState> {
  ReaderBloc({
    required this.bookId,
    required ReaderRepository readerRepository,
    required BookRepository bookRepository,
    ReadingProgressStore? progressStore,
  })  : _readerRepository = readerRepository,
        _bookRepository = bookRepository,
        _progressStore = progressStore ?? ReadingProgressStore(),
        super(const ReaderState()) {
    on<LoadPage>(_onLoadPage);
    on<WordTapped>(_onWordTapped);
    on<HideTranslation>(_onHideTranslation);
    on<NavigateToPage>(_onNavigateToPage);
    on<RefreshPage>(_onRefreshPage);
    on<PrefetchPage>(_onPrefetchPage);
  }

  final int bookId;
  final ReaderRepository _readerRepository;
  final BookRepository _bookRepository;
  final ReadingProgressStore _progressStore;

  final Map<int, _CachedPage> _cache = {};

  Future<void> _onLoadPage(LoadPage event, Emitter<ReaderState> emit) async {
    final cached = _cache[event.pageNumber];

    // Cache hit → swap content instantly, no loading spinner.
    if (cached != null) {
      emit(state.copyWith(
        isLoading: false,
        blocks: cached.blocks,
        pageFragments: cached.fragments,
        currentPage: event.pageNumber,
        isBarVisible: false,
        clearTargetFragment: true,
        clearSelection: true,
        clearError: true,
      ));
      _progressStore.setLastPage(bookId, event.pageNumber);
      _schedulePrefetch(event.pageNumber);
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final page = await _fetchPage(event.pageNumber);
      final totalPages = await _loadTotalPages();

      emit(state.copyWith(
        isLoading: false,
        blocks: page.blocks,
        pageFragments: page.fragments,
        currentPage: event.pageNumber,
        totalPages: totalPages,
        isBarVisible: false,
        clearTargetFragment: true,
        clearSelection: true,
        clearError: true,
      ));
      _progressStore.setLastPage(bookId, event.pageNumber);
      _schedulePrefetch(event.pageNumber);
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Fetches a page's blocks + fragments, using the in-memory cache when
  /// available. Stores the result in the cache.
  Future<_CachedPage> _fetchPage(int pageNumber) async {
    final cached = _cache[pageNumber];
    if (cached != null) return cached;

    final blocks = await _readerRepository.getPageBlocks(bookId, pageNumber);
    final blockIds = blocks.map((block) => block.id).toList();
    final fragments =
        await _readerRepository.getPageFragments(bookId, blockIds);

    final page = _CachedPage(blocks, fragments);
    _cache[pageNumber] = page;
    return page;
  }

  /// Queues a background load of the neighbouring page(s) so navigation feels
  /// instant. Bounded by `[1, totalPages]` and skips already-cached pages.
  void _schedulePrefetch(int currentPage) {
    final total = state.totalPages;
    final candidates = [currentPage + 1, currentPage - 1];
    for (final page in candidates) {
      if (page < 1) continue;
      if (total != null && page > total) continue;
      if (_cache.containsKey(page)) continue;
      add(PrefetchPage(page));
    }
  }

  Future<void> _onPrefetchPage(
    PrefetchPage event,
    Emitter<ReaderState> emit,
  ) async {
    if (_cache.containsKey(event.pageNumber)) return;
    try {
      await _fetchPage(event.pageNumber);
    } catch (_) {
      // Prefetch is best-effort; ignore failures so they don't surface as
      // errors. The real load will retry and report if needed.
    }
  }

  Future<int?> _loadTotalPages() async {
    if (state.totalPages != null) return state.totalPages;
    final book = await _bookRepository.getBookById(bookId);
    return book?.totalPages;
  }

  void _onWordTapped(WordTapped event, Emitter<ReaderState> emit) {
    if (state.pageFragments.isEmpty) return;

    // `fragmentOrder` is relative to its block, so it can't be used directly as
    // an index into the page-wide fragment list. Resolve the real index by
    // matching both the block and the fragment order.
    final index = state.pageFragments.indexWhere(
      (fragment) =>
          fragment.blockId == event.blockId &&
          fragment.fragmentOrder == event.fragmentOrder,
    );
    if (index == -1) return;

    // FLUTTER_DB_CONTRACT §4: look up the word_map entry by OFFSET. `charOffset`
    // is already the offset local to the fragment, so no `char_start`
    // subtraction is needed here. Which offset side we match — and which side we
    // highlight in the bar — is mirrored by the reading direction. `entry` may
    // be null (punctuation, omitted word, or word_map not yet aligned) → show
    // the bar without a highlight.
    final fragment = state.pageFragments[index];
    final isEnToEs = event.direction == TranslationDirection.enToEs;
    final entry = isEnToEs
        ? fragment.entryAtOffset(event.charOffset)
        : fragment.entryAtTransOffset(event.charOffset);

    // Bar shows the OPPOSITE language: enToEs highlights `trans_*` over the
    // Spanish text; esToEn highlights `orig_*` over the English text. The pill
    // reads "<body word> → <bar word>".
    emit(state.copyWith(
      isBarVisible: true,
      targetFragment: index,
      selectedBlockId: event.blockId,
      selectedFragmentOrder: event.fragmentOrder,
      selectedCharOffset: event.charOffset,
      highlightStart: isEnToEs ? entry?.transStart : entry?.origStart,
      highlightEnd: isEnToEs ? entry?.transEnd : entry?.origEnd,
      tappedBodyWord: isEnToEs ? entry?.original : entry?.translated,
      tappedBarWord: isEnToEs ? entry?.translated : entry?.original,
      clearHighlight: entry == null,
    ));
  }

  void _onHideTranslation(HideTranslation event, Emitter<ReaderState> emit) {
    emit(state.copyWith(isBarVisible: false, clearSelection: true));
  }

  void _onNavigateToPage(NavigateToPage event, Emitter<ReaderState> emit) {
    add(LoadPage(bookId: bookId, pageNumber: event.pageNumber));
  }

  void _onRefreshPage(RefreshPage event, Emitter<ReaderState> emit) {
    // Force a fresh fetch for the current page.
    _cache.remove(state.currentPage);
    add(LoadPage(bookId: bookId, pageNumber: state.currentPage));
  }
}
