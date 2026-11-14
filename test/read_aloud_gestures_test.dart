import 'dart:io';

import 'package:blackreader/core/settings/reader_settings.dart';
import 'package:blackreader/data/models/block_fragment_model.dart';
import 'package:blackreader/data/models/content_block_model.dart';
import 'package:blackreader/presentation/reader/widgets/text_block_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Georgia de Windows: con la fuente de test por defecto los toques por
/// coordenadas no caen en las palabras. Sin ella se saltan esos tests.
final File _georgia = File(r'C:\Windows\Fonts\georgia.ttf');

/// Se carga dentro de cada test: cargada en setUpAll no se aplica.
Future<void> _loadGeorgia() async {
  if (!_georgia.existsSync()) return;
  final bytes = _georgia.readAsBytesSync();
  await (FontLoader('Georgia')
        ..addFont(Future.value(ByteData.sublistView(bytes))))
      .load();
}

/// Gestos del audio en el texto: 1 toque (palabra), 2 toques (leer desde esa
/// palabra), mantener 2 s (leer el bloque), y el resaltado de la palabra que
/// suena.
void main() {
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

  Future<void> pump(
    WidgetTester tester, {
    void Function(int, int)? onWordTap,
    void Function(int, int)? onWordDoubleTap,
    void Function(int?, int?)? onWordLongPress,
    AudioWord? playingWord,
  }) async {
    await _loadGeorgia();
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderSettingsScope(
          settings: ReaderSettings(),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: TextBlockWidget(
                block: block,
                fragments: fragments,
                direction: TranslationDirection.enToEs,
                onWordTap: onWordTap ?? (_, _) {},
                onWordDoubleTap: onWordDoubleTap,
                onWordLongPress: onWordLongPress,
                playingWord: playingWord,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<String, TextSpan> words(WidgetTester tester) {
    final spans = <String, TextSpan>{};
    (tester.widget<RichText>(find.byType(RichText)).text as TextSpan)
        .visitChildren((span) {
      if (span is TextSpan && span.text != null && span.text!.trim().isNotEmpty) {
        spans[span.text!] = span;
      }
      return true;
    });
    return spans;
  }

  void tap(WidgetTester tester, String word) =>
      (words(tester)[word]!.recognizer as dynamic).onTap();

  group('toques', () {
    testWidgets('un toque es solo un toque', (tester) async {
      final taps = <(int, int)>[];
      final doubles = <(int, int)>[];
      await pump(
        tester,
        onWordTap: (order, offset) => taps.add((order, offset)),
        onWordDoubleTap: (order, offset) => doubles.add((order, offset)),
      );
      tap(tester, 'choose.');
      expect(taps, equals([(1, 8)]));
      expect(doubles, isEmpty);
    });

    testWidgets('dos toques seguidos leen desde esa palabra, y el toque sigue '
        'llegando (la barra de traducción no espera)', (tester) async {
      final taps = <(int, int)>[];
      final doubles = <(int, int)>[];
      await pump(
        tester,
        onWordTap: (order, offset) => taps.add((order, offset)),
        onWordDoubleTap: (order, offset) => doubles.add((order, offset)),
      );
      tap(tester, 'choose.');
      tap(tester, 'choose.');
      expect(doubles, equals([(1, 8)]));
      expect(taps.length, 2);
      // Un tercer toque empieza otra cuenta, no es otro doble.
      tap(tester, 'choose.');
      expect(doubles.length, 1);
    });

    testWidgets('sin audio no se detecta el doble toque', (tester) async {
      var taps = 0;
      await pump(tester, onWordTap: (_, _) => taps++);
      tap(tester, 'You');
      tap(tester, 'You');
      expect(taps, 2);
    });
  });

  group('mantener pulsado', skip: !_georgia.existsSync(), () {
    testWidgets('a los 2 s lee el bloque de la palabra pulsada',
        (tester) async {
      final presses = <(int?, int?)>[];
      var taps = 0;
      await pump(
        tester,
        onWordTap: (_, _) => taps++,
        onWordLongPress: (order, offset) => presses.add((order, offset)),
      );
      // Sobre la primera letra de "Which", a media altura de la línea (con
      // interlineado 1,85 el borde de arriba es aire, no letra).
      final origin = tester.getTopLeft(find.byType(RichText));
      final gesture = await tester.startGesture(origin + const Offset(4, 15));
      await tester.pump(const Duration(seconds: 1));
      expect(presses, isEmpty, reason: 'con 1 s todavía no');
      await tester.pump(const Duration(milliseconds: 1100));
      expect(presses, equals([(0, 0)]));
      await gesture.up();
      await tester.pump();
      expect(taps, 0, reason: 'la pulsación larga no abre la traducción');
    });

    testWidgets('soltar antes de 2 s es un toque normal', (tester) async {
      final presses = <(int?, int?)>[];
      final taps = <(int, int)>[];
      await pump(
        tester,
        onWordTap: (order, offset) => taps.add((order, offset)),
        onWordLongPress: (order, offset) => presses.add((order, offset)),
      );
      final origin = tester.getTopLeft(find.byType(RichText));
      final gesture = await tester.startGesture(origin + const Offset(4, 15));
      await tester.pump(const Duration(milliseconds: 800));
      await gesture.up();
      await tester.pump();
      expect(presses, isEmpty);
      expect(taps, equals([(0, 0)]));
    });
  });

  testWidgets('se resalta la palabra que está sonando', (tester) async {
    // "can" ocupa 28–31 de original_content (24 + 4 dentro del fragmento).
    await pump(
      tester,
      playingWord: const AudioWord(
        charStart: 28,
        charEnd: 31,
        startMs: 1000,
        endMs: 1300,
      ),
    );
    final spans = words(tester);
    expect(spans['can']!.style!.backgroundColor, isNotNull);
    expect(spans['You']!.style!.backgroundColor, isNull);
    expect(spans['choose.']!.style!.backgroundColor, isNull);
  });
}
