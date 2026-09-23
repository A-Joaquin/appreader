import '../../core/settings/reader_settings.dart';

/// Tipo de problema que el lector reporta.
///
/// Los valores de [wire] son los del enum `word_report_type` en Postgres
/// (`supabase/migrations/0002_word_reports.sql`). `missing_translation` venía
/// de antes y se conserva: es el de los reportes que ya estaban guardados.
enum ReportKind {
  badTranslation('bad_translation', 'La traducción está mal'),
  badFormat('bad_format', 'El texto está mal formateado'),
  missingTranslation('missing_translation', 'La traducción no se ve o falta'),
  other('other', 'Otro problema');

  const ReportKind(this.wire, this.label);

  /// Valor tal cual viaja a la base de datos.
  final String wire;

  /// Texto que ve el usuario.
  final String label;

  static ReportKind fromWire(String? value) => ReportKind.values.firstWhere(
        (k) => k.wire == value,
        orElse: () => ReportKind.other,
      );
}

/// Un reporte hecho desde la barra de traducción.
///
/// Apunta al fragmento que se estaba leyendo y guarda además la palabra tocada,
/// su contrapartida, el offset dentro del fragmento y una copia del texto en
/// los dos idiomas, para poder localizar el problema exacto aunque el libro se
/// recargue más tarde.
class WordReport {
  const WordReport({
    this.id,
    required this.bookId,
    this.blockId,
    this.fragmentId,
    this.pageNumber,
    this.direction,
    this.tappedWord,
    this.counterpartWord,
    this.charOffset,
    this.originalText,
    this.translatedText,
    required this.kind,
    this.message,
    this.status = 'open',
    this.createdAt,
    this.userId,
  });

  final int? id;
  final int bookId;
  final int? blockId;
  final int? fragmentId;
  final int? pageNumber;

  /// Hacia dónde se estaba leyendo: `'en_to_es'` o `'es_to_en'`.
  final String? direction;

  /// Palabra que el usuario tocó, en el idioma del cuerpo.
  final String? tappedWord;

  /// La que le salía enfrente en la barra (null si el word_map no la tenía).
  final String? counterpartWord;

  /// Offset de [tappedWord] dentro del fragmento.
  final int? charOffset;

  /// Copia del fragmento en inglés y en español.
  final String? originalText;
  final String? translatedText;

  final ReportKind kind;
  final String? message;

  /// 'open' u 'resolved'. En la base es una columna text con CHECK, no un enum.
  final String status;
  final DateTime? createdAt;
  final String? userId;

  /// Etiqueta de [direction] tal como la guarda la base de datos.
  static String wireDirection(TranslationDirection direction) =>
      direction == TranslationDirection.esToEn ? 'es_to_en' : 'en_to_es';

  /// Payload para insertar en Supabase. [userId] lo pone el emisor porque la
  /// política RLS exige `user_id = auth.uid()`.
  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId,
        'book_id': bookId,
        if (blockId != null) 'block_id': blockId,
        if (fragmentId != null) 'fragment_id': fragmentId,
        if (pageNumber != null) 'page_number': pageNumber,
        if (direction != null) 'direction': direction,
        if (tappedWord != null && tappedWord!.isNotEmpty)
          'tapped_word': tappedWord,
        if (counterpartWord != null && counterpartWord!.isNotEmpty)
          'counterpart_word': counterpartWord,
        if (charOffset != null) 'char_offset': charOffset,
        if (originalText != null && originalText!.isNotEmpty)
          'original_text': originalText,
        if (translatedText != null && translatedText!.isNotEmpty)
          'translated_text': translatedText,
        'report_type': kind.wire,
        if (message != null && message!.isNotEmpty) 'message': message,
      };

  /// Serialización para la cola local de pendientes (sin `user_id`: al
  /// reenviar se usa el de la sesión de ese momento).
  Map<String, dynamic> toJson() => {
        'book_id': bookId,
        'block_id': blockId,
        'fragment_id': fragmentId,
        'page_number': pageNumber,
        'direction': direction,
        'tapped_word': tappedWord,
        'counterpart_word': counterpartWord,
        'char_offset': charOffset,
        'original_text': originalText,
        'translated_text': translatedText,
        'report_type': kind.wire,
        'message': message,
      };

  factory WordReport.fromJson(Map<String, dynamic> json) => WordReport(
        id: json['id'] as int?,
        bookId: json['book_id'] as int,
        blockId: json['block_id'] as int?,
        fragmentId: json['fragment_id'] as int?,
        pageNumber: json['page_number'] as int?,
        direction: json['direction'] as String?,
        tappedWord: json['tapped_word'] as String?,
        counterpartWord: json['counterpart_word'] as String?,
        charOffset: json['char_offset'] as int?,
        originalText: json['original_text'] as String?,
        translatedText: json['translated_text'] as String?,
        kind: ReportKind.fromWire(json['report_type'] as String?),
        message: json['message'] as String?,
        status: (json['status'] as String?) ?? 'open',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        userId: json['user_id'] as String?,
      );
}
