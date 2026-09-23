import 'dart:convert';

import 'package:blackreader/data/models/block_report_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// El reporte que se queda en la cola local cuando no hay conexión.
///
/// `ReportStore` guarda cada reporte pendiente como JSON en SharedPreferences y
/// lo reenvía tal cual al volver la red. Si la ida y vuelta pierde un campo, el
/// reporte se sube incompleto y no hay forma de saberlo: el insert no falla.
void main() {
  const report = BlockReport(
    bookId: 1,
    blockId: 48,
    pageNumber: 9,
    fragmentOrder: 2,
    word: 'databases',
    excerpt: 'Which databases to use?',
    kind: ReportKind.badFormat,
    message: 'El título sale pegado al párrafo.',
  );

  test('la cola local no pierde nada al ir y volver', () {
    final back = BlockReport.fromJson(
      jsonDecode(jsonEncode(report.toJson())) as Map<String, dynamic>,
    );

    expect(back.bookId, report.bookId);
    expect(back.blockId, report.blockId);
    expect(back.pageNumber, report.pageNumber);
    expect(back.fragmentOrder, report.fragmentOrder);
    expect(back.word, report.word);
    expect(back.excerpt, report.excerpt);
    expect(back.kind, report.kind);
    expect(back.message, report.message);
  });

  test('el payload lleva las columnas de block_reports', () {
    final insert = report.toInsert('11111111-2222-3333-4444-555555555555');

    // Las columnas de supabase/migrations/0002_block_reports.sql. `user_id` lo
    // pone el emisor porque la política RLS exige user_id = auth.uid().
    expect(
      insert.keys.toSet(),
      equals({
        'user_id',
        'book_id',
        'block_id',
        'page_number',
        'fragment_order',
        'word',
        'excerpt',
        'kind',
        'message',
      }),
    );
    // `kind` viaja con el valor del enum de Postgres, no con la etiqueta que
    // ve el usuario.
    expect(insert['kind'], 'bad_format');
  });

  test('los campos vacíos no se mandan', () {
    const minimo = BlockReport(bookId: 3, kind: ReportKind.badTranslation);
    final insert = minimo.toInsert('uid');

    expect(insert.keys.toSet(), equals({'user_id', 'book_id', 'kind'}));
    // `status` y `created_at` los pone la base de datos por defecto.
    expect(insert.containsKey('status'), isFalse);
  });

  test('un kind desconocido no revienta la lectura', () {
    // Si algún día se añade un tipo nuevo en Postgres, un cliente viejo tiene
    // que poder seguir leyendo la lista del panel.
    final back = BlockReport.fromJson(const {
      'id': 7,
      'book_id': 1,
      'kind': 'kind_que_no_existe_todavia',
      'status': 'open',
    });
    expect(back.kind, ReportKind.other);
  });
}
