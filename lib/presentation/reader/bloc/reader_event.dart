import 'package:equatable/equatable.dart';

import '../../../core/settings/reader_settings.dart';

abstract class ReaderEvent extends Equatable {
  const ReaderEvent();

  @override
  List<Object?> get props => [];
}

class LoadPage extends ReaderEvent {
  const LoadPage({required this.bookId, required this.pageNumber});

  final int bookId;
  final int pageNumber;

  @override
  List<Object?> get props => [bookId, pageNumber];
}

class WordTapped extends ReaderEvent {
  const WordTapped({
    required this.blockId,
    required this.fragmentOrder,
    required this.charOffset,
    required this.direction,
  });

  final int blockId;
  final int fragmentOrder;

  /// Character offset of the tapped word's start, relative to the rendered
  /// fragment text — `original_text` in [TranslationDirection.enToEs] or
  /// `translated_text` in [TranslationDirection.esToEn] (offsetLocal in
  /// FLUTTER_DB_CONTRACT §4).
  final int charOffset;

  /// Reading direction at tap time; decides which offset side to look up.
  final TranslationDirection direction;

  @override
  List<Object?> get props => [blockId, fragmentOrder, charOffset, direction];
}

class HideTranslation extends ReaderEvent {
  const HideTranslation();
}

class NavigateToPage extends ReaderEvent {
  const NavigateToPage(this.pageNumber);

  final int pageNumber;

  @override
  List<Object?> get props => [pageNumber];
}

class RefreshPage extends ReaderEvent {
  const RefreshPage();
}

/// Internal event: load a page into the cache in the background (no UI change)
/// so navigating to it later is instant.
class PrefetchPage extends ReaderEvent {
  const PrefetchPage(this.pageNumber);

  final int pageNumber;

  @override
  List<Object?> get props => [pageNumber];
}
