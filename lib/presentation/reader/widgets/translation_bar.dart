import 'package:flutter/material.dart';

import '../../../core/settings/reader_settings.dart';
import '../../../data/models/block_fragment_model.dart';

class TranslationBar extends StatefulWidget {
  const TranslationBar({
    super.key,
    required this.fragments,
    required this.targetIndex,
    required this.direction,
    this.highlightStart,
    this.highlightEnd,
    this.bodyWord,
    this.barWord,
    this.onClose,
  });

  final List<BlockFragment> fragments;

  /// Real index into [fragments] of the tapped fragment (already resolved).
  final int? targetIndex;

  /// Reading direction: decides which language the chips show (the OPPOSITE of
  /// the body — Spanish in enToEs, English in esToEn).
  final TranslationDirection direction;

  /// Range to highlight inside the target fragment's BAR text — the counterpart
  /// of the exact word the user tapped (FLUTTER_DB_CONTRACT §4). Both `null`
  /// when the tapped word has no word_map entry.
  final int? highlightStart;
  final int? highlightEnd;

  /// The tapped word ([bodyWord], body language) and its counterpart
  /// ([barWord], bar language), shown as "body → bar" in a strip below the bar.
  /// Both `null` when the tapped word has no word_map entry.
  final String? bodyWord;
  final String? barWord;

  /// Dismisses the bar (close button).
  final VoidCallback? onClose;

  @override
  State<TranslationBar> createState() => _TranslationBarState();
}

class _TranslationBarState extends State<TranslationBar> {
  static const Color _highlightColor = Color(0xFFFFF3BF);

  /// Marks the highlighted translated word so we can center it in the viewport.
  final GlobalKey _highlightKey = GlobalKey();

  /// Marks the whole target chip — used to center on it when the tapped word
  /// has no highlight (no word_map entry).
  final GlobalKey _fragmentKey = GlobalKey();

  @override
  void didUpdateWidget(TranslationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-center whenever the tapped target or its highlight changes.
    final changed = widget.targetIndex != oldWidget.targetIndex ||
        widget.highlightStart != oldWidget.highlightStart ||
        widget.highlightEnd != oldWidget.highlightEnd ||
        widget.bodyWord != oldWidget.bodyWord;
    if (widget.targetIndex != null && changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelection());
    }
  }

  /// Scrolls so the highlighted translated word sits in the middle of the bar
  /// (or the whole fragment, when there's no word highlight).
  void _centerSelection() {
    if (!mounted) return;
    final context = _highlightKey.currentContext ?? _fragmentKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5, // center within the horizontal scroll viewport
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fragments.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    final bodyWord = widget.bodyWord;
    final barWord = widget.barWord;
    final hasWordPair = bodyWord != null &&
        bodyWord.isNotEmpty &&
        barWord != null &&
        barWord.isNotEmpty;

    return Material(
      elevation: 4,
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compact, single-line bar. Fragments are laid out in a row and the
            // reader swipes left/right to read across them.
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          for (var i = 0; i < widget.fragments.length; i++)
                            _buildChip(i, scheme),
                        ],
                      ),
                    ),
                  ),
                  if (widget.onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Cerrar',
                      visualDensity: VisualDensity.compact,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                      onPressed: widget.onClose,
                    ),
                ],
              ),
            ),
            // Word pair strip, just below the bar so it doesn't overlap it.
            if (hasWordPair) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: scheme.onSurface.withValues(alpha: 0.08),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: _WordPairPill(bodyWord: bodyWord, barWord: barWord),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(int index, ColorScheme scheme) {
    final fragment = widget.fragments[index];
    final isTarget = index == widget.targetIndex;

    // The bar shows the opposite language to the body. In esToEn the chip is the
    // English original; in enToEs it's the Spanish translation (falling back to
    // the original when a fragment isn't translated yet).
    final String text;
    if (widget.direction == TranslationDirection.esToEn) {
      text = fragment.originalText;
    } else {
      final translated = fragment.translatedText;
      text = (translated != null && translated.isNotEmpty)
          ? translated
          : fragment.originalText;
    }

    final style = TextStyle(
      fontSize: 15,
      fontWeight: isTarget ? FontWeight.w600 : FontWeight.w400,
      color: scheme.onSurface,
    );

    final start = widget.highlightStart;
    final end = widget.highlightEnd;
    final canHighlight = isTarget &&
        text.isNotEmpty &&
        start != null &&
        end != null &&
        start >= 0 &&
        end <= text.length &&
        start < end;

    final Widget content;
    if (canHighlight) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (start > 0)
            Text(text.substring(0, start),
                style: style, maxLines: 1, softWrap: false),
          // The highlighted word carries the key we center on.
          Container(
            key: _highlightKey,
            decoration: BoxDecoration(
              color: _highlightColor,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(text.substring(start, end),
                style: style.copyWith(color: Colors.black),
                maxLines: 1,
                softWrap: false),
          ),
          if (end < text.length)
            Text(text.substring(end),
                style: style, maxLines: 1, softWrap: false),
        ],
      );
    } else if (isTarget) {
      // Target fragment whose tapped word has no entry: dotted underline hint.
      content = Text(
        text,
        style: style.copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
          decorationColor: scheme.onSurface.withValues(alpha: 0.35),
        ),
        maxLines: 1,
        softWrap: false,
      );
    } else {
      content = Text(text, style: style, maxLines: 1, softWrap: false);
    }

    return Container(
      key: isTarget ? _fragmentKey : null,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTarget
            ? scheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: content,
    );
  }
}

/// Pill showing the tapped word and its counterpart: `worked → trabajó`
/// (enToEs) or `trabajó → worked` (esToEn). [bodyWord] is the word tapped in
/// the body; [barWord] is its equivalent shown in the bar.
class _WordPairPill extends StatelessWidget {
  const _WordPairPill({required this.bodyWord, required this.barWord});

  final String bodyWord;
  final String barWord;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: bodyWord,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            TextSpan(
              text: '  →  ',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            TextSpan(
              text: barWord,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ],
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
      ),
    );
  }
}
