import 'package:flutter/material.dart';

import '../../../data/models/block_report_model.dart';

/// Hoja inferior para reportar un problema en el bloque que se está leyendo.
///
/// Se abre con el icono de bandera de la barra de traducción. El usuario elige
/// el tipo de problema y, si quiere, escribe un detalle; con "Otro problema" el
/// texto pasa a ser obligatorio (es lo único que explica el reporte).
///
/// Devuelve el [BlockReport] a enviar, o `null` si se cerró sin reportar.
class ReportSheet extends StatefulWidget {
  const ReportSheet({
    super.key,
    required this.bookId,
    this.blockId,
    this.pageNumber,
    this.fragmentOrder,
    this.word,
    this.excerpt,
  });

  final int bookId;
  final int? blockId;
  final int? pageNumber;
  final int? fragmentOrder;

  /// Palabra seleccionada en la barra, si la había.
  final String? word;

  /// Texto del bloque/fragmento reportado, para guardarlo con el reporte.
  final String? excerpt;

  /// Abre la hoja y devuelve el reporte a enviar (o null si se canceló).
  static Future<BlockReport?> show(
    BuildContext context, {
    required int bookId,
    int? blockId,
    int? pageNumber,
    int? fragmentOrder,
    String? word,
    String? excerpt,
  }) {
    return showModalBottomSheet<BlockReport>(
      context: context,
      isScrollControlled: true, // deja sitio al teclado
      showDragHandle: true,
      builder: (_) => ReportSheet(
        bookId: bookId,
        blockId: blockId,
        pageNumber: pageNumber,
        fragmentOrder: fragmentOrder,
        word: word,
        excerpt: excerpt,
      ),
    );
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final TextEditingController _messageCtrl = TextEditingController();
  ReportKind? _kind;
  bool _messageMissing = false;

  bool get _needsMessage => _kind == ReportKind.other;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final kind = _kind;
    if (kind == null) return;
    final message = _messageCtrl.text.trim();
    if (_needsMessage && message.isEmpty) {
      setState(() => _messageMissing = true);
      return;
    }
    Navigator.of(context).pop(
      BlockReport(
        bookId: widget.bookId,
        blockId: widget.blockId,
        pageNumber: widget.pageNumber,
        fragmentOrder: widget.fragmentOrder,
        word: widget.word,
        excerpt: widget.excerpt,
        kind: kind,
        message: message.isEmpty ? null : message,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      // Sube con el teclado para que el campo de texto no quede tapado.
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reportar un problema', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              _contextLabel(),
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),

            RadioGroup<ReportKind>(
              groupValue: _kind,
              onChanged: (v) => setState(() {
                _kind = v;
                _messageMissing = false;
              }),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final kind in ReportKind.values)
                    RadioListTile<ReportKind>(
                      value: kind,
                      title: Text(kind.label),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            TextField(
              controller: _messageCtrl,
              maxLines: 3,
              minLines: 2,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_messageMissing) setState(() => _messageMissing = false);
              },
              decoration: InputDecoration(
                labelText: _needsMessage
                    ? 'Describe el problema'
                    : 'Mensaje (opcional)',
                hintText: 'Cuéntanos qué está mal…',
                border: const OutlineInputBorder(),
                errorText:
                    _messageMissing ? 'Escribe qué problema encontraste.' : null,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _kind == null ? null : _send,
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Enviar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "Página 12 · «palabra»" — para que se vea qué se está reportando.
  String _contextLabel() {
    final parts = <String>[];
    if (widget.pageNumber != null) parts.add('Página ${widget.pageNumber}');
    final word = widget.word;
    if (word != null && word.isNotEmpty) parts.add('«$word»');
    return parts.isEmpty ? 'En este bloque' : parts.join('  ·  ');
  }
}
