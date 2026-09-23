import 'package:blackreader/core/settings/reader_settings.dart';
import 'package:blackreader/data/models/block_fragment_model.dart';
import 'package:blackreader/data/models/content_block_model.dart';
import 'package:blackreader/presentation/reader/widgets/text_block_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Qué salto de línea sobrevive al render del lector.
///
/// Los bloques de aquí están copiados TAL CUAL de la base de datos real
/// (`content_blocks` / `block_fragments`, book_id 1 y 6), con sus `char_start`
/// y `char_end`: es justo lo que hace que el caso del título funcione, así que
/// no sirve de nada inventarse los offsets.
void main() {
  /// Pinta el bloque y devuelve el texto plano resultante, con los saltos que
  /// el widget decidió conservar.
  Future<String> render(
    WidgetTester tester,
    ContentBlock block,
    List<BlockFragment> fragments, {
    TranslationDirection direction = TranslationDirection.enToEs,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderSettingsScope(
          settings: ReaderSettings(),
          child: Scaffold(
            body: TextBlockWidget(
              block: block,
              fragments: fragments,
              direction: direction,
              onWordTap: (_, _) {},
            ),
          ),
        ),
      ),
    );
    final richText = tester.widget<RichText>(find.byType(RichText));
    return richText.text.toPlainText();
  }

  group('salto de línea', () {
    // Bloque 48 del libro 1: el caso del PENDIENTE. El fragmentador dejó el
    // título en su propio fragmento y el `\n` quedó FUERA de los dos, en el
    // hueco entre char_end=23 y char_start=24.
    const tituloContent = 'Which databases to use?\n'
        'You can choose between a traditional relational database and a '
        'non-relational database. Let\nus examine their differences.';
    final tituloBlock = ContentBlock(
      id: 48,
      bookId: 1,
      pageNumber: 9,
      sequenceOrder: 47,
      blockType: 'text',
      originalContent: tituloContent,
    );
    final tituloFragments = [
      const BlockFragment(
        id: 1,
        blockId: 48,
        fragmentOrder: 0,
        originalText: 'Which databases to use?',
        translatedText: '¿Qué bases de datos usar?',
        charStart: 0,
        charEnd: 23,
      ),
      const BlockFragment(
        id: 2,
        blockId: 48,
        fragmentOrder: 1,
        originalText: 'You can choose between a traditional relational '
            'database and a non-relational database.',
        translatedText: 'Puedes elegir entre una base de datos relacional '
            'tradicional y una base de datos no relacional.',
        charStart: 24,
        charEnd: 111,
      ),
      const BlockFragment(
        id: 3,
        blockId: 48,
        fragmentOrder: 2,
        originalText: 'Let\nus examine their differences.',
        translatedText: 'Examinemos sus diferencias.',
        charStart: 112,
        charEnd: 145,
      ),
    ];

    testWidgets('el título no se pega a su párrafo', (tester) async {
      final text = await render(tester, tituloBlock, tituloFragments);
      expect(text, startsWith('Which databases to use?\nYou can choose'));
    });

    testWidgets('el corte de columna dentro del párrafo NO rompe',
        (tester) async {
      final text = await render(tester, tituloBlock, tituloFragments);
      // "…database. Let\nus examine…" es un corte del PDF a media frase.
      expect(text, contains('Let us examine their differences.'));
    });

    testWidgets('en español el título también queda en su línea',
        (tester) async {
      final text = await render(
        tester,
        tituloBlock,
        tituloFragments,
        direction: TranslationDirection.esToEn,
      );
      expect(text, startsWith('¿Qué bases de datos usar?\nPuedes elegir'));
    });

    // Bloque 5 del libro 1: prosa justificada. Ninguno de sus dos `\n` es un
    // salto de verdad; antes se rompían porque el ancho de columna se medía
    // sobre los fragmentos pegados con espacio y salía inflado.
    testWidgets('la prosa justificada no se parte', (tester) async {
      const content = 'Alex Xu is an experienced software engineer and '
          'entrepreneur. Previously, he worked at\nTwitter, Apple, Zynga and '
          'Oracle. He received his M.S. from Carnegie Mellon University.\n'
          'He has a passion for designing and implementing complex systems.';
      final block = ContentBlock(
        id: 5,
        bookId: 1,
        pageNumber: 1,
        sequenceOrder: 4,
        blockType: 'text',
        originalContent: content,
      );
      final fragments = [
        const BlockFragment(
          id: 5,
          blockId: 5,
          fragmentOrder: 0,
          originalText:
              'Alex Xu is an experienced software engineer and entrepreneur.',
          charStart: 0,
          charEnd: 61,
        ),
        const BlockFragment(
          id: 6,
          blockId: 5,
          fragmentOrder: 1,
          originalText:
              'Previously, he worked at\nTwitter, Apple, Zynga and Oracle.',
          charStart: 62,
          charEnd: 120,
        ),
        const BlockFragment(
          id: 7,
          blockId: 5,
          fragmentOrder: 2,
          originalText:
              'He received his M.S. from Carnegie Mellon University.',
          charStart: 121,
          charEnd: 174,
        ),
        const BlockFragment(
          id: 8,
          blockId: 5,
          fragmentOrder: 3,
          originalText: 'He has a passion for designing and implementing '
              'complex systems.',
          charStart: 175,
          charEnd: 239,
        ),
      ];
      final text = await render(tester, block, fragments);
      expect(text, isNot(contains('\n')));
      expect(text, contains('he worked at Twitter'));
    });

    // Bloque 2006 del libro 6: diálogo, una intervención por línea. Aquí TODOS
    // los `\n` son de verdad aunque la línea vaya llena — y los fragmentos que
    // comparten línea ("Rosa: Oh yeah?" + "Where were you?") siguen juntos.
    testWidgets('el diálogo va una intervención por línea', (tester) async {
      const content = 'Page 91, Exs. 4B and 4C\n'
          'Diego: I was on vacation last week.\n'
          'Rosa: Oh yeah? Where were you?\n'
          'Diego: I was in London.\n'
          'Rosa: And how was it?';
      final block = ContentBlock(
        id: 2006,
        bookId: 6,
        pageNumber: 91,
        sequenceOrder: 12,
        blockType: 'text',
        originalContent: content,
      );
      final fragments = [
        const BlockFragment(
          id: 20,
          blockId: 2006,
          fragmentOrder: 0,
          originalText: 'Page 91, Exs. 4B and 4C\n'
              'Diego: I was on vacation last week.',
          charStart: 0,
          charEnd: 59,
        ),
        const BlockFragment(
          id: 21,
          blockId: 2006,
          fragmentOrder: 1,
          originalText: 'Rosa: Oh yeah?',
          charStart: 60,
          charEnd: 74,
        ),
        const BlockFragment(
          id: 22,
          blockId: 2006,
          fragmentOrder: 2,
          originalText: 'Where were you?',
          charStart: 75,
          charEnd: 90,
        ),
        const BlockFragment(
          id: 23,
          blockId: 2006,
          fragmentOrder: 3,
          originalText: 'Diego: I was in London.',
          charStart: 91,
          charEnd: 114,
        ),
        const BlockFragment(
          id: 24,
          blockId: 2006,
          fragmentOrder: 4,
          originalText: 'Rosa: And how was it?',
          charStart: 115,
          charEnd: 136,
        ),
      ];
      final text = await render(tester, block, fragments);
      expect(
        text.split('\n'),
        equals(const [
          'Page 91, Exs. 4B and 4C',
          'Diego: I was on vacation last week.',
          // Dos fragmentos, una sola línea: el hueco entre ellos era un
          // espacio, no un salto.
          'Rosa: Oh yeah? Where were you?',
          'Diego: I was in London.',
          'Rosa: And how was it?',
        ]),
      );
    });
  });

  group('offsets de las palabras', () {
    // Lo que se le pasa a onWordTap tiene que seguir siendo el offset DENTRO
    // del fragmento (FLUTTER_DB_CONTRACT §3), aunque ahora el texto se recorra
    // sobre el bloque entero.
    testWidgets('el tap devuelve el offset relativo al fragmento',
        (tester) async {
      const content = 'Which databases to use?\nYou can choose.';
      final block = ContentBlock(
        id: 48,
        bookId: 1,
        blockType: 'text',
        originalContent: content,
      );
      final fragments = [
        const BlockFragment(
          id: 1,
          blockId: 48,
          fragmentOrder: 0,
          originalText: 'Which databases to use?',
          charStart: 0,
          charEnd: 23,
        ),
        const BlockFragment(
          id: 2,
          blockId: 48,
          fragmentOrder: 1,
          originalText: 'You can choose.',
          charStart: 24,
          charEnd: 39,
        ),
      ];

      final taps = <(int, int)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderSettingsScope(
            settings: ReaderSettings(),
            child: Scaffold(
              body: TextBlockWidget(
                block: block,
                fragments: fragments,
                direction: TranslationDirection.enToEs,
                onWordTap: (order, offset) => taps.add((order, offset)),
              ),
            ),
          ),
        ),
      );

      // Se disparan los recognizers directamente: tocar por coordenadas exige
      // la fuente Georgia cargada, y aquí lo que se comprueba es el offset.
      final spans = <TextSpan>[];
      (tester.widget<RichText>(find.byType(RichText)).text as TextSpan)
          .visitChildren((span) {
        if (span is TextSpan && span.recognizer != null) spans.add(span);
        return true;
      });

      final words = {for (final s in spans) s.text: s};
      // "choose." es la 3ª palabra del SEGUNDO fragmento: offset 8 dentro de
      // "You can choose.", no 32 dentro del bloque.
      expect(words.containsKey('choose.'), isTrue);
      (words['choose.']!.recognizer as dynamic).onTap();
      expect(taps.single, equals((1, 8)));
    });
  });
}
