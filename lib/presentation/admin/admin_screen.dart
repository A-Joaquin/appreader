import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin-only panel. Lists every user with their reading progress per book,
/// last reading activity, downloaded books, and a ban / unban switch.
///
/// Access is gated by the router (`/admin` is admin-only) and by RLS
/// (admin policies on `profiles` / `reading_progress` / `user_downloads`).
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  List<_UserRow> _users = const [];

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
      final profiles = await _client
          .from('profiles')
          .select('id, display_name, role, status, created_at')
          .order('created_at');
      final progress = await _client.from('reading_progress').select(
          'user_id, book_id, last_page, total_pages, last_active_at');
      final downloads = await _client
          .from('user_downloads')
          .select('user_id, book_id, downloaded_at');
      final books = await _client.from('books').select('id, title, total_pages');

      final titleById = <int, String>{};
      final pagesById = <int, int?>{};
      for (final b in books as List) {
        titleById[b['id'] as int] = (b['title'] as String?) ?? 'Libro';
        pagesById[b['id'] as int] = b['total_pages'] as int?;
      }

      final progByUser = <String, List<_BookProgress>>{};
      DateTime? lastActiveFor(String uid) => progByUser[uid]
          ?.map((p) => p.lastActive)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

      for (final r in progress as List) {
        final uid = r['user_id'] as String;
        final bookId = r['book_id'] as int;
        (progByUser[uid] ??= []).add(_BookProgress(
          title: titleById[bookId] ?? 'Libro #$bookId',
          lastPage: (r['last_page'] as int?) ?? 1,
          totalPages: (r['total_pages'] as int?) ?? pagesById[bookId],
          lastActive: DateTime.tryParse(r['last_active_at'] as String? ?? ''),
        ));
      }

      final downByUser = <String, List<String>>{};
      for (final d in downloads as List) {
        final uid = d['user_id'] as String;
        final bookId = d['book_id'] as int;
        (downByUser[uid] ??= []).add(titleById[bookId] ?? 'Libro #$bookId');
      }

      _users = (profiles as List).map((p) {
        final uid = p['id'] as String;
        return _UserRow(
          id: uid,
          name: (p['display_name'] as String?) ?? '(sin nombre)',
          role: (p['role'] as String?) ?? 'user',
          status: (p['status'] as String?) ?? 'active',
          progress: progByUser[uid] ?? const [],
          downloads: downByUser[uid] ?? const [],
          lastActive: lastActiveFor(uid),
        );
      }).toList();
    } catch (e) {
      _error = 'No se pudo cargar: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setBanned(_UserRow u, bool banned) async {
    final newStatus = banned ? 'banned' : 'active';
    try {
      await _client
          .from('profiles')
          .update({'status': newStatus}).eq('id', u.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _users.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No hay usuarios.')),
                          ],
                        )
                      : ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, i) => _UserTile(
                            user: _users[i],
                            onBanChanged: (b) => _setBanned(_users[i], b),
                          ),
                        ),
                ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onBanChanged});

  final _UserRow user;
  final ValueChanged<bool> onBanChanged;

  @override
  Widget build(BuildContext context) {
    final isBanned = user.status == 'banned';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
        ),
        title: Row(
          children: [
            Expanded(child: Text(user.name)),
            if (user.role == 'admin')
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Chip(
                  label: Text('admin'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        subtitle: Text(
          [
            if (isBanned) 'BANEADO' else 'activo',
            'última lectura: ${_fmtAgo(user.lastActive)}',
          ].join(' · '),
          style: TextStyle(
            color: isBanned ? Theme.of(context).colorScheme.error : null,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              const Icon(Icons.block, size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Banear usuario')),
              Switch(
                value: isBanned,
                onChanged: user.role == 'admin' ? null : onBanChanged,
              ),
            ],
          ),
          if (user.role == 'admin')
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No puedes banear a un administrador.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          const Divider(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Progreso',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          if (user.progress.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Sin progreso todavía.'),
            )
          else
            ...user.progress.map((p) => _ProgressRow(p)),
          const Divider(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Descargados (${user.downloads.length})',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          if (user.downloads.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Ninguno.'),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: user.downloads
                    .map((t) => Chip(
                          label: Text(t),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow(this.p);

  final _BookProgress p;

  @override
  Widget build(BuildContext context) {
    final total = (p.totalPages != null && p.totalPages! > 0) ? p.totalPages! : null;
    final pct = total != null ? (p.lastPage / total).clamp(0.0, 1.0) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(p.title)),
              Text(
                total != null
                    ? 'pág. ${p.lastPage}/$total'
                    : 'pág. ${p.lastPage}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtAgo(DateTime? t) {
  if (t == null) return 'nunca';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'ahora';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  return 'hace ${d.inDays} d';
}

class _UserRow {
  const _UserRow({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    required this.progress,
    required this.downloads,
    required this.lastActive,
  });

  final String id;
  final String name;
  final String role;
  final String status;
  final List<_BookProgress> progress;
  final List<String> downloads;
  final DateTime? lastActive;
}

class _BookProgress {
  const _BookProgress({
    required this.title,
    required this.lastPage,
    required this.totalPages,
    required this.lastActive,
  });

  final String title;
  final int lastPage;
  final int? totalPages;
  final DateTime? lastActive;
}
