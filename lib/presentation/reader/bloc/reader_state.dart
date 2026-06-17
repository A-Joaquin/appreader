import 'package:equatable/equatable.dart';

import '../../../data/models/block_fragment_model.dart';
import '../../../data/models/content_block_model.dart';

class ReaderState extends Equatable {
  const ReaderState({
    this.blocks = const [],
    this.pageFragments = const [],
    this.isBarVisible = false,
    this.targetFragment,
    this.selectedBlockId,
    this.selectedFragmentOrder,
    this.selectedCharOffset,
    this.highlightStart,
    this.highlightEnd,
    this.tappedBodyWord,
    this.tappedBarWord,
    this.currentPage = 1,
    this.totalPages,
    this.isLoading = true,
    this.error,
  });

  final List<ContentBlock> blocks;
  final List<BlockFragment> pageFragments;
  final bool isBarVisible;
  final int? targetFragment;

  /// Identifies the exact tapped word so it can be highlighted in the text.
  /// [selectedCharOffset] is the tapped word's start offset within its
  /// fragment's `original_text`.
  final int? selectedBlockId;
  final int? selectedFragmentOrder;
  final int? selectedCharOffset;

  /// Resolved range to highlight inside the target fragment's BAR text (the
  /// counterpart of the tapped word). In enToEs that's `translated_text`; in
  /// esToEn it's `original_text`. Both `null` when the tapped word has no
  /// `word_map` entry — the bar still shows the full sentence, just without a
  /// yellow highlight.
  final int? highlightStart;
  final int? highlightEnd;

  /// The tapped word ([tappedBodyWord], shown in the body's language) and its
  /// counterpart ([tappedBarWord], the bar's language), rendered as a
  /// "body → bar" pair. Both `null` when the tapped word has no entry.
  final String? tappedBodyWord;
  final String? tappedBarWord;

  final int currentPage;
  final int? totalPages;
  final bool isLoading;
  final String? error;

  ReaderState copyWith({
    List<ContentBlock>? blocks,
    List<BlockFragment>? pageFragments,
    bool? isBarVisible,
    int? targetFragment,
    bool clearTargetFragment = false,
    int? selectedBlockId,
    int? selectedFragmentOrder,
    int? selectedCharOffset,
    int? highlightStart,
    int? highlightEnd,
    String? tappedBodyWord,
    String? tappedBarWord,
    bool clearHighlight = false,
    bool clearSelection = false,
    int? currentPage,
    int? totalPages,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ReaderState(
      blocks: blocks ?? this.blocks,
      pageFragments: pageFragments ?? this.pageFragments,
      isBarVisible: isBarVisible ?? this.isBarVisible,
      targetFragment: clearTargetFragment
          ? null
          : (targetFragment ?? this.targetFragment),
      selectedBlockId:
          clearSelection ? null : (selectedBlockId ?? this.selectedBlockId),
      selectedFragmentOrder: clearSelection
          ? null
          : (selectedFragmentOrder ?? this.selectedFragmentOrder),
      selectedCharOffset: clearSelection
          ? null
          : (selectedCharOffset ?? this.selectedCharOffset),
      highlightStart: (clearSelection || clearHighlight)
          ? null
          : (highlightStart ?? this.highlightStart),
      highlightEnd: (clearSelection || clearHighlight)
          ? null
          : (highlightEnd ?? this.highlightEnd),
      tappedBodyWord: (clearSelection || clearHighlight)
          ? null
          : (tappedBodyWord ?? this.tappedBodyWord),
      tappedBarWord: (clearSelection || clearHighlight)
          ? null
          : (tappedBarWord ?? this.tappedBarWord),
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        blocks,
        pageFragments,
        isBarVisible,
        targetFragment,
        selectedBlockId,
        selectedFragmentOrder,
        selectedCharOffset,
        highlightStart,
        highlightEnd,
        tappedBodyWord,
        tappedBarWord,
        currentPage,
        totalPages,
        isLoading,
        error,
      ];
}
