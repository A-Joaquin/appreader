import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/settings/reader_settings.dart';
import '../../../data/models/block_fragment_model.dart';
import '../../../data/models/content_block_model.dart';

class TextBlockWidget extends StatefulWidget {
  const TextBlockWidget({
    super.key,
    required this.block,
    required this.fragments,
    required this.onWordTap,
    required this.direction,
    this.selectedBlockId,
    this.selectedFragmentOrder,
    this.selectedCharOffset,
  });

  final ContentBlock block;
  final List<BlockFragment> fragments;

  /// Which language to render in the body. In [TranslationDirection.esToEn] the
  /// body shows each fragment's `translated_text`; the tap offsets are then
  /// local to that Spanish text.
  final TranslationDirection direction;

  /// Called with the tapped word's `(fragmentOrder, charOffset)`, where
  /// `charOffset` is the word's start offset within the fragment's
  /// `original_text` (offsetLocal in FLUTTER_DB_CONTRACT §4).
  final void Function(int fragmentOrder, int charOffset) onWordTap;
  final int? selectedBlockId;
  final int? selectedFragmentOrder;
  final int? selectedCharOffset;

  @override
  State<TextBlockWidget> createState() => _TextBlockWidgetState();
}

class _TextBlockWidgetState extends State<TextBlockWidget> {
  /// Tap recognizers cached per `(fragmentOrder, charOffset)` so we don't leak
  /// a fresh recognizer on every rebuild. A `TextSpan` never disposes its own
  /// recognizer, so they MUST be disposed manually in [dispose].
  final Map<_WordKey, TapGestureRecognizer> _recognizers = {};

  TapGestureRecognizer _recognizerFor(int fragmentOrder, int charOffset) {
    final key = _WordKey(fragmentOrder, charOffset);
    return _recognizers.putIfAbsent(
      key,
      () => TapGestureRecognizer()
        ..onTap = () => widget.onWordTap(fragmentOrder, charOffset),
    );
  }

  @override
  void didUpdateWidget(TextBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ScrollablePositionedList recycles this State for other blocks. When the
    // block changes, the cached recognizers belong to the previous block's
    // words, so drop them. A direction change re-renders the other language, so
    // the offsets (cache keys) no longer line up either — drop them too.
    if (oldWidget.block.id != widget.block.id ||
        oldWidget.direction != widget.direction) {
      _disposeRecognizers();
    }
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final scheme = Theme.of(context).colorScheme;
    final fontScale = ReaderSettingsScope.of(context).fontScale;
    final baseStyle = TextStyle(
      fontSize: 16 * fontScale,
      height: 1.85,
      color: scheme.onSurface,
      fontFamily: 'Georgia',
    );
    // Resaltamos SOLO con color + fondo, nunca con fontWeight. Engrosar la
    // palabra (w700) la ensancha respecto a la versión normal, por lo que las
    // letras "se recorren" y el texto siguiente se reacomoda (reflow). Mantener
    // el mismo grosor que baseStyle deja el resalte estable, sin mover nada.
    final selectedStyle = baseStyle.copyWith(
      color: scheme.primary,
      backgroundColor: scheme.primary.withValues(alpha: 0.18),
    );

    final blockFragments = widget.fragments
        .where((fragment) => fragment.blockId == block.id)
        .toList()
      ..sort((a, b) => a.fragmentOrder.compareTo(b.fragmentOrder));

    final spans = <InlineSpan>[];

    if (blockFragments.isEmpty) {
      spans.add(TextSpan(
        text: _toSpaces(block.originalContent ?? ''),
        style: baseStyle,
      ));
    } else {
      final isSelectedBlock = block.id == widget.selectedBlockId;
      final esToEn = widget.direction == TranslationDirection.esToEn;
      for (final fragment in blockFragments) {
        // Body language depends on direction. In esToEn we show the Spanish
        // translation; if a fragment isn't translated yet, fall back to the
        // English original so the page is never blank. Offsets stay local to
        // whichever text we render.
        final translated = fragment.translatedText;
        final text = (esToEn && translated != null && translated.isNotEmpty)
            ? translated
            : fragment.originalText;
        final isSelectedFragment = isSelectedBlock &&
            fragment.fragmentOrder == widget.selectedFragmentOrder;

        // Walk the fragment splitting it into word tokens (runs of non-space)
        // and whitespace, tracking each word's start offset. We DON'T alter the
        // text length (newlines preserved as 1 char) so offsets stay aligned
        // with word_map — see FLUTTER_DB_CONTRACT §5.3.
        var i = 0;
        while (i < text.length) {
          final start = i;
          final isSpace = _isWhitespace(text.codeUnitAt(i));
          while (i < text.length &&
              _isWhitespace(text.codeUnitAt(i)) == isSpace) {
            i++;
          }
          final token = text.substring(start, i);

          if (isSpace) {
            // Los \n / \r / \t vienen del wrap del PDF, no son saltos reales.
            // Se muestran como espacio para que el texto fluya y envuelva según
            // el ancho de pantalla. Se reemplaza 1 char por 1 char (no se
            // colapsan) para no desalinear los offsets del word_map — ver
            // FLUTTER_DB_CONTRACT §5.3.
            spans.add(TextSpan(text: _toSpaces(token), style: baseStyle));
            continue;
          }

          final wordStart = start;
          final isSelected =
              isSelectedFragment && wordStart == widget.selectedCharOffset;
          spans.add(TextSpan(
            text: token,
            style: isSelected ? selectedStyle : baseStyle,
            recognizer: _recognizerFor(fragment.fragmentOrder, wordStart),
          ));
        }
        // Separator between consecutive fragments of the same block.
        spans.add(TextSpan(text: ' ', style: baseStyle));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: RichText(text: TextSpan(children: spans)),
    );
  }

  /// Convierte saltos de línea / tabs / retornos de carro en espacios
  /// manteniendo la longitud (1 char por 1 char) para no mover los offsets.
  static String _toSpaces(String s) => s.replaceAll(RegExp(r'[\n\r\t]'), ' ');

  static bool _isWhitespace(int codeUnit) {
    // space, tab, newline, carriage return.
    return codeUnit == 0x20 ||
        codeUnit == 0x09 ||
        codeUnit == 0x0A ||
        codeUnit == 0x0D;
  }
}

/// Identity of a tappable word within a block: its fragment order plus its
/// start offset inside that fragment.
class _WordKey {
  const _WordKey(this.fragmentOrder, this.charOffset);

  final int fragmentOrder;
  final int charOffset;

  @override
  bool operator ==(Object other) =>
      other is _WordKey &&
      other.fragmentOrder == fragmentOrder &&
      other.charOffset == charOffset;

  @override
  int get hashCode => Object.hash(fragmentOrder, charOffset);
}
