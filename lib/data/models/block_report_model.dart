/// Tipo de problema que el lector reporta sobre un bloque.
///
/// Los valores de [wire] son los del enum `report_kind` en Postgres
/// (`supabase/migrations/0002_block_reports.sql`).
enum ReportKind {
  badTranslation('bad_translation', 'La traducción está mal'),
  badFormat('bad_format', 'El texto está mal formateado'),
  translationNotShown('translation_not_shown', 'La traducción no se ve bien'),
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

/// Un reporte sobre un bloque del libro.
class BlockReport {
  const BlockReport({
    this.id,
    required this.bookId,
    this.blockId,
    this.pageNumber,
    this.fragmentOrder,
    this.word,
    this.excerpt,
    required this.kind,
    this.message,
    this.status = 'open',
    this.createdAt,
    this.userId,
    this.userName,
  });

  final int? id;
  final int bookId;
  final int? blockId;
  final int? pageNumber;
  final int? fragmentOrder;

  /// Palabra seleccionada en el momento de reportar, si la había.
  final String? word;

  /// Copia del texto reportado, para poder leer el problema aunque el bloque
  /// cambie más tarde.
  final String? excerpt;

  final ReportKind kind;
  final String? message;
  final String status; // 'open' | 'resolved'
  final DateTime? createdAt;
  final String? userId;

  /// Solo se rellena al leer desde el panel de administración.
  final String? userName;

  /// Payload para insertar en Supabase. [userId] lo pone el emisor porque la
  /// política RLS exige `user_id = auth.uid()`.
  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId,
        'book_id': bookId,
        if (blockId != null) 'block_id': blockId,
        if (pageNumber != null) 'page_number': pageNumber,
        if (fragmentOrder != null) 'fragment_order': fragmentOrder,
        if (word != null && word!.isNotEmpty) 'word': word,
        if (excerpt != null && excerpt!.isNotEmpty) 'excerpt': excerpt,
        'kind': kind.wire,
        if (message != null && message!.isNotEmpty) 'message': message,
      };

  /// Serialización para la cola local de pendientes (sin `user_id`: al
  /// reenviar se usa el de la sesión de ese momento).
  Map<String, dynamic> toJson() => {
        'book_id': bookId,
        'block_id': blockId,
        'page_number': pageNumber,
        'fragment_order': fragmentOrder,
        'word': word,
        'excerpt': excerpt,
        'kind': kind.wire,
        'message': message,
      };

  factory BlockReport.fromJson(Map<String, dynamic> json) => BlockReport(
        id: json['id'] as int?,
        bookId: json['book_id'] as int,
        blockId: json['block_id'] as int?,
        pageNumber: json['page_number'] as int?,
        fragmentOrder: json['fragment_order'] as int?,
        word: json['word'] as String?,
        excerpt: json['excerpt'] as String?,
        kind: ReportKind.fromWire(json['kind'] as String?),
        message: json['message'] as String?,
        status: (json['status'] as String?) ?? 'open',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        userId: json['user_id'] as String?,
      );
}
