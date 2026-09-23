import 'dart:convert';

import 'package:blackreader/core/settings/reader_settings.dart';
import 'package:blackreader/data/models/word_report_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// El reporte que se queda en la cola local cuando no hay conexión.
///
/// `ReportStore` guarda cada reporte pendiente como JSON en SharedPreferences y
/// lo reenvía tal cual al volver la red. Si la ida y vuelta pierde un campo, el
/// reporte se sube incompleto y no hay forma de saberlo: el insert no falla.
void main() {
  const report = WordReport(
    bookId: 1,
    blockId: 48,
    fragmentId: 3333,
    pageNumber: 9,
    direction: 'en_to_es',
    tappedWord: 'databases',
    counterpartWord: 'bases de datos',
    charOffset: 6,
    originalText: 'Which databases to use?',
    translatedText: '¿Qué bases de datos usar?',
    kind: ReportKind.badFormat,
    message: 'El título sale pegado al párrafo.',
  );

  test('la cola local no pierde nada al ir y volver', () {
    final back = WordReport.fromJson(
      jsonDecode(jsonEncode(report.toJson())) as Map<String, dynamic>,
    );

    expect(back.bookId, report.bookId);
    expect(back.blockId, report.blockId);
    expect(back.fragmentId, report.fragmentId);
    expect(back.pageNumber, report.pageNumber);
    expect(back.direction, report.direction);
    expect(back.tappedWord, report.tappedWord);
    expect(back.counterpartWord, report.counterpartWord);
    expect(back.charOffset, report.charOffset);
    expect(back.originalText, report.originalText);
    expect(back.translatedText, report.translatedText);
    expect(back.kind, report.kind);
    expect(back.message, report.message);
  });

  test('el payload lleva las columnas de word_reports', () {
    final insert = report.toInsert('11111111-2222-3333-4444-555555555555');

    // Las columnas de la tabla real (ver supabase/migrations/0002_word_reports.sql,
    // que solo le añade message / status / resolved_*). `user_id` lo pone el
    // emisor porque la política RLS exige user_id = auth.uid().
    expect(
      insert.keys.toSet(),
      equals({
        'user_id',
        'book_id',
        'block_id',
        'fragment_id',
        'page_number',
        'direction',
        'tapped_word',
        'counterpart_word',
        'char_offset',
        'original_text',
        'translated_text',
        'report_type',
        'message',
      }),
    );
    // El tipo viaja con el valor del enum de Postgres, no con la etiqueta que
    // ve el usuario, y en la columna que existe (`report_type`).
    expect(insert['report_type'], 'bad_format');
  });

  test('los campos vacíos no se mandan', () {
    const minimo = WordReport(bookId: 3, kind: ReportKind.badTranslation);
    final insert = minimo.toInsert('uid');

    expect(insert.keys.toSet(), equals({'user_id', 'book_id', 'report_type'}));
    // `status` y `created_at` los pone la base de datos por defecto.
    expect(insert.containsKey('status'), isFalse);
  });

  test('la dirección viaja como la espera la base', () {
    expect(
      WordReport.wireDirection(TranslationDirection.enToEs),
      'en_to_es',
    );
    expect(
      WordReport.wireDirection(TranslationDirection.esToEn),
      'es_to_en',
    );
  });

  test('se leen los reportes que ya estaban guardados', () {
    // Fila real de word_reports, de antes de esta migración: sin message y sin
    // status. El panel de admin tiene que poder mostrarla igual.
    final vieja = WordReport.fromJson(const {
      'id': 1,
      'user_id': 'd2b6a7d6-8076-457b-a614-1c631290d498',
      'book_id': 5,
      'block_id': 1898,
      'fragment_id': 3333,
      'page_number': 47,
      'report_type': 'missing_translation',
      'direction': 'en_to_es',
      'tapped_word': 'thing',
      'counterpart_word': null,
      'char_offset': 4,
      'original_text': 'The thing with Chiara happened so easily.',
      'translated_text': 'Lo que pasó con Chiara ocurrió con facilidad.',
      'created_at': '2026-06-30T17:16:59.294387+00:00',
    });

    expect(vieja.kind, ReportKind.missingTranslation);
    expect(vieja.message, isNull);
    expect(vieja.status, 'open'); // el default, para que salga en pendientes
    expect(vieja.counterpartWord, isNull);
  });

  test('un report_type desconocido no revienta la lectura', () {
    // Si algún día se añade un tipo nuevo en Postgres, un cliente viejo tiene
    // que poder seguir leyendo la lista del panel.
    final back = WordReport.fromJson(const {
      'id': 7,
      'book_id': 1,
      'report_type': 'tipo_que_no_existe_todavia',
      'status': 'open',
    });
    expect(back.kind, ReportKind.other);
  });
}
