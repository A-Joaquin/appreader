import 'package:blackreader/core/settings/reader_settings.dart';
import 'package:blackreader/data/models/block_fragment_model.dart';
import 'package:blackreader/presentation/reader/widgets/translation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La barra de traducción con fragmentos que traen varias viñetas.
///
/// El chip es de UNA línea (`maxLines: 1`), así que un `\n` del PDF dentro del
/// fragmento cortaba el texto ahí y el resto de la traducción no se veía. En el
/// corpus real hay 230 fragmentos traducidos con viñeta, y varios meten dos o
/// tres entradas en el mismo fragmento separadas por `\n`.
void main() {
  /// Todo el texto que pinta la barra, chip a chip.
  List<String> barTexts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .toList();

  Future<void> pump(
    WidgetTester tester,
    List<BlockFragment> fragments, {
    int? targetIndex,
    int? highlightStart,
    int? highlightEnd,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: ReaderSettingsScope(
          settings: ReaderSettings(),
          child: Scaffold(
            body: TranslationBar(
              fragments: fragments,
              targetIndex: targetIndex,
              direction: TranslationDirection.enToEs,
              highlightStart: highlightStart,
              highlightEnd: highlightEnd,
            ),
          ),
        ),
      ),
    );
  }

  // Fragmento real (libro 1): dos viñetas dentro del mismo fragmento.
  const fragment = BlockFragment(
    id: 1,
    blockId: 1,
    fragmentOrder: 0,
    originalText: '• Your application requires super-low latency.\n'
        '• Your data are unstructured.',
    translatedText: '• Tu aplicación requiere una latencia extremadamente '
        'baja.\n• Tus datos son no estructurados.',
    charStart: 0,
    charEnd: 75,
  );

  testWidgets('no se pierde lo que va detrás del salto de línea',
      (tester) async {
    await pump(tester, const [fragment], targetIndex: 0);
    final texts = barTexts(tester);
    // Las dos viñetas, en un solo chip y en una sola línea.
    expect(
      texts,
      contains('• Tu aplicación requiere una latencia extremadamente baja. '
          '• Tus datos son no estructurados.'),
    );
    expect(texts.any((t) => t.contains('\n')), isFalse);
  });

  testWidgets('el resaltado sigue cuadrando tras aplanar', (tester) async {
    // "estructurados" empieza en el offset 78 del translated_text, contando el
    // \n como UN carácter — que es justo lo que garantiza aplanar a espacios
    // 1 char por 1 char en vez de quitar el salto.
    const start = 78;
    const end = 91;
    expect(fragment.translatedText!.substring(start, end), 'estructurados');

    await pump(
      tester,
      const [fragment],
      targetIndex: 0,
      highlightStart: start,
      highlightEnd: end,
    );
    expect(barTexts(tester), contains('estructurados'));
  });
}
