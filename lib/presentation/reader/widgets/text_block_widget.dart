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

      final rendered = _render(block, blockFragments, esToEn);
      final text = rendered.text;

      // Ancho de columna del PDF en ESTE bloque: la línea más larga. Sirve de
      // vara de medir para distinguir un corte de línea del PDF (la línea iba
      // llena) de un salto de verdad (la línea se cortó mucho antes: fin de
      // párrafo, título o subtítulo). Ver [_lineIsShort].
      final reference = _columnWidth(text);

      // ¿Este bloque es una lista de líneas (diálogo, ejercicio, reseñas) en
      // vez de un párrafo justificado? Entonces TODOS sus saltos son de
      // verdad. Ver [_isLineStructured].
      final structured = _isLineStructured(rendered.sourceText);

      // Caracteres acumulados en la línea que se está pintando. Se lleva a
      // mano porque una línea del PDF puede atravesar varios fragmentos.
      var lineLength = 0;

      // Fragmento por el que va el recorrido, para no buscarlo en cada
      // palabra: [_Rendered.spans] está ordenado igual que el texto.
      var spanIndex = 0;

      var i = 0;
      while (i < text.length) {
        final start = i;
        final isSpace = _isWhitespace(text.codeUnitAt(i));
        while (i < text.length && _isWhitespace(text.codeUnitAt(i)) == isSpace) {
          i++;
        }
        final token = text.substring(start, i);

        if (isSpace) {
          // La mayoría de los \n / \r / \t son el corte de línea del PDF, no
          // un salto de verdad: se pintan como espacio para que el texto
          // fluya y envuelva según el ancho de pantalla.
          //
          // Nunca se rompe si lo que sigue continúa la frase (ver
          // [_continuesSentence]). Cumplido eso, se conserva el salto en tres
          // casos:
          //  1. El bloque está estructurado por líneas (una intervención de
          //     diálogo, una reseña o un ejercicio por línea): ahí ningún
          //     salto es un corte de columna.
          //  2. Detrás viene un marcador de lista («•», «2.», «- »). Sin
          //     esto la lista se aplana en un párrafo corrido y los números
          //     quedan sueltos a media frase, porque el fragmentador parte
          //     por oraciones y, como «2.» acaba en punto, deja el marcador
          //     de la entrada siguiente colgando del fragmento anterior.
          //  3. La línea se cortó mucho antes del ancho de la columna: era
          //     un fin de párrafo o un título pegado a su texto.
          //
          // Esto solo cambia lo que se PINTA. Los offsets que se pasan al
          // recognizer se calculan sobre el texto original, así que el
          // word_map sigue alineado (FLUTTER_DB_CONTRACT §5.3).
          final breaksLine = token.contains('\n') &&
              i < text.length &&
              !_continuesSentence(text, i) &&
              (structured ||
                  _startsListMarker(text, i) ||
                  _lineIsShort(lineLength, reference));
          spans.add(TextSpan(
            text: breaksLine ? '\n' : _toSpaces(token),
            style: baseStyle,
          ));
          if (breaksLine) {
            lineLength = 0;
          } else {
            lineLength += token.length;
          }
          continue;
        }

        // ¿De qué fragmento es esta palabra? El offset que se le pasa al
        // recognizer es RELATIVO AL FRAGMENTO, que es lo que espera el
        // word_map (FLUTTER_DB_CONTRACT §3).
        while (spanIndex < rendered.spans.length &&
            rendered.spans[spanIndex].end <= start) {
          spanIndex++;
        }
        final owner = spanIndex < rendered.spans.length &&
                rendered.spans[spanIndex].start <= start
            ? rendered.spans[spanIndex]
            : null;

        if (owner == null) {
          // Texto del bloque que no pertenece a ningún fragmento (no debería
          // pasar: los huecos son solo espacios). Se pinta, pero no se toca.
          spans.add(TextSpan(text: token, style: baseStyle));
        } else {
          final wordStart = start - owner.start;
          final isSelected = isSelectedBlock &&
              owner.fragmentOrder == widget.selectedFragmentOrder &&
              wordStart == widget.selectedCharOffset;
          spans.add(TextSpan(
            text: token,
            style: isSelected ? selectedStyle : baseStyle,
            recognizer: _recognizerFor(owner.fragmentOrder, wordStart),
          ));
        }
        lineLength += token.length;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: RichText(text: TextSpan(children: spans)),
    );
  }

  /// Arma el texto que se va a pintar para el bloque.
  ///
  /// La clave está en NO volver a pegar los fragmentos con un espacio. El
  /// fragmentador corta por oraciones y deja fuera lo que había entre una y la
  /// siguiente — y ahí es justo donde vive el `\n` que separa un título de su
  /// párrafo. Ese texto no se perdió: sigue en `original_content` del bloque,
  /// entre el `char_end` de un fragmento y el `char_start` del siguiente. Así
  /// que en inglés se pinta el trozo de bloque tal cual, con sus saltos, y se
  /// mapea cada palabra a su fragmento por offsets.
  ///
  /// En español no hay texto de bloque (la traducción es por fragmento), así
  /// que se pegan las traducciones usando como separador el hueco REAL del
  /// inglés: si allí había un salto, aquí también lo hay.
  static _Rendered _render(
    ContentBlock block,
    List<BlockFragment> fragments,
    bool esToEn,
  ) {
    final content = block.originalContent;
    final usable = content != null && _offsetsMatch(content, fragments);

    if (!esToEn && usable) {
      final base = fragments.first.charStart!;
      final text = content.substring(base, fragments.last.charEnd!);
      return _Rendered(
        text,
        [
          for (final fragment in fragments)
            _FragmentSpan(
              fragment.charStart! - base,
              fragment.charEnd! - base,
              fragment.fragmentOrder,
            ),
        ],
        text,
      );
    }

    final buffer = StringBuffer();
    final spans = <_FragmentSpan>[];
    for (var k = 0; k < fragments.length; k++) {
      final fragment = fragments[k];
      final translated = fragment.translatedText;
      final body = (esToEn && translated != null && translated.isNotEmpty)
          ? translated
          : fragment.originalText;
      final start = buffer.length;
      buffer.write(body);
      spans.add(_FragmentSpan(start, buffer.length, fragment.fragmentOrder));
      if (k < fragments.length - 1) {
        buffer.write(usable
            ? content.substring(fragment.charEnd!, fragments[k + 1].charStart!)
            : ' ');
      }
    }
    final rendered = buffer.toString();
    return _Rendered(
      rendered,
      spans,
      usable
          ? content.substring(
              fragments.first.charStart!, fragments.last.charEnd!)
          : rendered,
    );
  }

  /// ¿Los offsets del bloque son de fiar? Se comprueba de verdad (que el trozo
  /// recortado sea exactamente el `original_text`) porque de ahí cuelga el
  /// word_map entero: ante la menor duda se vuelven a pegar los fragmentos a
  /// mano, que es como se pintaba antes.
  static bool _offsetsMatch(String content, List<BlockFragment> fragments) {
    var previousEnd = -1;
    for (final fragment in fragments) {
      final start = fragment.charStart;
      final end = fragment.charEnd;
      if (start == null || end == null) return false;
      if (start < previousEnd || start > end || end > content.length) {
        return false;
      }
      if (content.substring(start, end) != fragment.originalText) return false;
      previousEnd = end;
    }
    return true;
  }

  /// Convierte saltos de línea / tabs / retornos de carro en espacios
  /// manteniendo la longitud (1 char por 1 char) para no mover los offsets.
  static String _toSpaces(String s) => s.replaceAll(RegExp(r'[\n\r\t]'), ' ');

  /// Marcador de lista al principio de una línea: viñeta, guion seguido de
  /// espacio, o número con punto o paréntesis («•», «- », «2.», «3)»).
  ///
  /// El guion y el número exigen lo que va detrás para no confundirse con texto
  /// normal: «2.5 millones» no abre lista, «2. Otro paso» sí. El número también
  /// vale al final del texto, que es justo como quedan los marcadores colgados
  /// por el fragmentador.
  /// Sin `^`: [RegExp.matchAsPrefix] ya ancla en la posición indicada, y un `^`
  /// solo casaría en el carácter 0 del fragmento (era el fallo de la primera
  /// versión: nunca coincidía a media frase).
  static final RegExp _listMarker = RegExp(
    r'(?:[•‣◦▪●·]'
    r'|[-–—](?=[ \t])'
    r'|\d{1,3}[.)](?=[ \t]|$))',
  );

  /// ¿El texto en [index] empieza una entrada de lista?
  static bool _startsListMarker(String text, int index) =>
      index < text.length && _listMarker.matchAsPrefix(text, index) != null;

  /// Ancho de columna del bloque: la línea más larga de su texto.
  static int _columnWidth(String text) {
    var width = 0;
    for (final line in text.split('\n')) {
      final length = line.trimRight().length;
      if (length > width) width = length;
    }
    return width;
  }

  /// Final de frase: puntuación de cierre, admitiendo comillas o paréntesis
  /// detrás (por ejemplo «...Ask away.'» o «(ver arriba).»).
  static final RegExp _sentenceEnd = RegExp('[.?!:]["\'’”»)\\]]*\$');

  /// Proporción de líneas que han de cerrar frase para dar el bloque por
  /// estructurado. Medido sobre el corpus real: la distribución es bimodal —
  /// la prosa justificada se queda en 0.0–0.5, los diálogos y ejercicios
  /// saltan a 0.7–1.0, y entre medias casi no hay nada. El umbral se pone en
  /// ese valle.
  static const double _structuredRatio = 0.65;

  /// ¿El bloque está estructurado por líneas en vez de ser un párrafo?
  ///
  /// En un párrafo justificado la línea se corta donde se acaba el ancho, casi
  /// siempre a media frase. Si en cambio casi todas las líneas del bloque
  /// cierran frase, el PDF no estaba envolviendo texto: estaba poniendo una
  /// entrada por línea (cada interlocutor de un diálogo, cada punto de un
  /// ejercicio, cada reseña). Ahí ningún salto es un corte de columna, así que
  /// se respetan todos.
  ///
  /// Hacen falta 3 líneas (2 saltos) para que la proporción signifique algo.
  static bool _isLineStructured(String text) {
    final lines = text.split('\n');
    if (lines.length < 3) return false;
    var closed = 0;
    for (var i = 0; i < lines.length - 1; i++) {
      if (_sentenceEnd.hasMatch(lines[i].trimRight())) closed++;
    }
    return closed / (lines.length - 1) >= _structuredRatio;
  }

  /// Proporción del ancho de columna por debajo de la cual una línea se
  /// considera cortada a propósito. Medido sobre el corpus real: con 0.75
  /// separa títulos y fines de párrafo sin partir frases.
  static const double _shortLineRatio = 0.75;

  /// ¿La línea que acaba aquí se cortó mucho antes del ancho de la columna?
  /// Entonces no la cortó el ancho: era un fin de párrafo o un título.
  static bool _lineIsShort(int lineLength, int reference) {
    if (reference <= 0 || lineLength <= 0) return false;
    return lineLength < reference * _shortLineRatio;
  }

  /// ¿Lo que empieza en [index] viene a continuar la frase anterior?
  ///
  /// Una minúscula detrás de un salto es casi siempre una línea que el PDF
  /// envolvió por ancho, y partirla ahí molesta mucho más que dejar dos líneas
  /// cortas juntas. Dígitos y símbolos no cuentan como minúscula (para ellos
  /// toLowerCase y toUpperCase dan lo mismo).
  static bool _continuesSentence(String text, int index) {
    final next = text[index];
    return next.toLowerCase() == next && next.toUpperCase() != next;
  }

  static bool _isWhitespace(int codeUnit) {
    // space, tab, newline, carriage return.
    return codeUnit == 0x20 ||
        codeUnit == 0x09 ||
        codeUnit == 0x0A ||
        codeUnit == 0x0D;
  }
}

/// Texto que se pinta para un bloque, con el mapa de qué tramo es de qué
/// fragmento y el texto original del PDF (para decidir la estructura, que no
/// depende del idioma en que se esté leyendo).
class _Rendered {
  const _Rendered(this.text, this.spans, this.sourceText);

  final String text;
  final List<_FragmentSpan> spans;
  final String sourceText;
}

/// Tramo de [_Rendered.text] que pertenece a un fragmento.
class _FragmentSpan {
  const _FragmentSpan(this.start, this.end, this.fragmentOrder);

  final int start; // inclusive
  final int end; // exclusivo
  final int fragmentOrder;
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
