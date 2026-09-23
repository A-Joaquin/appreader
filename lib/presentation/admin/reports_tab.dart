import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/word_report_model.dart';
import '../../data/repositories/report_store.dart';

/// Pestaña de reportes del panel de administración.
///
/// Lista lo que los lectores han reportado desde la barra de traducción, con el
/// libro, la página, la palabra y el texto exacto del problema, y permite
/// marcarlo como resuelto. Solo carga algo para un admin (lo impone la RLS).
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  final ReportStore _store = ReportStore();

  bool _loading = true;
  String? _error;
  List<WordReport> _reports = const [];
  Map<int, String> _bookTitles = const {};
  Map<String, String> _userNames = const {};
  bool _onlyOpen = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final reports = await _store.fetchAll();
      final books = await client.from('books').select('id, title');
      final profiles = await client.from('profiles').select('id, display_name');

      _bookTitles = {
        for (final b in books as List)
          b['id'] as int: (b['title'] as String?) ?? 'Libro',
      };
      _userNames = {
        for (final p in profiles as List)
          p['id'] as String: (p['display_name'] as String?) ?? '(sin nombre)',
      };
      _reports = reports;
    } catch (e) {
      _error = 'No se pudieron cargar los reportes: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleResolved(WordReport report) async {
    final id = report.id;
    if (id == null) return;
    final resolve = report.status != 'resolved';
    try {
      await _store.setResolved(id, resolve);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar: $e')),
        );
      }
    }
  }

  List<WordReport> get _visible => _onlyOpen
      ? _reports.where((r) => r.status != 'resolved').toList()
      : _reports;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final openCount = _reports.where((r) => r.status != 'resolved').length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  openCount == 0
                      ? 'Sin reportes pendientes'
                      : '$openCount pendiente${openCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const Text('Solo pendientes'),
              Switch(
                value: _onlyOpen,
                onChanged: (v) => setState(() => _onlyOpen = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _visible.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No hay reportes que mostrar.')),
                    ],
                  )
                : ListView.builder(
                    itemCount: _visible.length,
                    itemBuilder: (context, i) {
                      final report = _visible[i];
                      return _ReportTile(
                        report: report,
                        bookTitle: _bookTitles[report.bookId] ??
                            'Libro #${report.bookId}',
                        userName: _userNames[report.userId] ?? 'Usuario',
                        onToggleResolved: () => _toggleResolved(report),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.report,
    required this.bookTitle,
    required this.userName,
    required this.onToggleResolved,
  });

  final WordReport report;
  final String bookTitle;
  final String userName;
  final VoidCallback onToggleResolved;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final resolved = report.status == 'resolved';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  resolved ? Icons.check_circle : Icons.flag,
                  size: 18,
                  color: resolved ? Colors.green : scheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.kind.label,
                    style: textTheme.titleSmall,
                  ),
                ),
                if (report.createdAt != null)
                  Text(
                    _shortDate(report.createdAt!),
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                bookTitle,
                if (report.pageNumber != null) 'pág. ${report.pageNumber}',
                if (report.tappedWord != null && report.tappedWord!.isNotEmpty)
                  _wordPair(report),
                userName,
              ].join('  ·  '),
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (report.message != null && report.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(report.message!, style: textTheme.bodyMedium),
            ],
            if (_hasExcerpt(report)) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (report.originalText != null &&
                        report.originalText!.isNotEmpty)
                      Text(
                        report.originalText!,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    if (report.translatedText != null &&
                        report.translatedText!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '→ ${report.translatedText}',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onToggleResolved,
                icon: Icon(
                  resolved ? Icons.undo : Icons.check,
                  size: 18,
                ),
                label: Text(resolved ? 'Reabrir' : 'Marcar resuelto'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "«palabra» → «traducción»", o solo la palabra si el word_map no tenía
  /// contrapartida.
  static String _wordPair(WordReport report) {
    final counterpart = report.counterpartWord;
    return counterpart != null && counterpart.isNotEmpty
        ? '«${report.tappedWord}» → «$counterpart»'
        : '«${report.tappedWord}»';
  }

  static bool _hasExcerpt(WordReport report) =>
      (report.originalText != null && report.originalText!.isNotEmpty) ||
      (report.translatedText != null && report.translatedText!.isNotEmpty);

  String _shortDate(DateTime utc) {
    final d = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
}
