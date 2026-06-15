import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists the last page the reader was on, **per user and per book**.
///
/// Offline-first: the local value (`shared_preferences`) is the source of
/// truth for resuming and works without network. Every save is also pushed to
/// Supabase `reading_progress` (best-effort) so the admin panel can show each
/// user's progress and last reading time. A failed/offline server write never
/// affects the local save.
///
/// Keys are namespaced by user id (`last_page_<uid>_<bookId>`) so two accounts
/// on the same device never see each other's progress. Legacy un-namespaced
/// keys from before auth existed are migrated on login.
class ReadingProgressStore {
  static const String _prefix = 'last_page_';

  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  String _key(String uid, int bookId) => '$_prefix${uid}_$bookId';
  String _legacyKey(int bookId) => '$_prefix$bookId';

  /// Last saved page for [bookId] for the current user, or `1` if none.
  Future<int> getLastPage(int bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uid;
    if (uid == null) {
      // No session (shouldn't happen post-auth). Fall back to legacy key.
      final legacy = prefs.getInt(_legacyKey(bookId));
      return (legacy != null && legacy >= 1) ? legacy : 1;
    }
    final page = prefs.getInt(_key(uid, bookId));
    if (page != null && page >= 1) return page;
    // Local cache miss (e.g. a freshly-installed device before the login pull
    // finishes): fall back to the server so cross-device resume is reliable.
    final remote = await _fetchServerPage(uid, bookId);
    if (remote != null && remote >= 1) {
      await prefs.setInt(_key(uid, bookId), remote);
      return remote;
    }
    return 1;
  }

  /// Reads one book's last page for [uid] from the server, or null on
  /// miss/offline.
  Future<int?> _fetchServerPage(String uid, int bookId) async {
    try {
      final row = await _client
          .from('reading_progress')
          .select('last_page')
          .eq('user_id', uid)
          .eq('book_id', bookId)
          .maybeSingle();
      return row?['last_page'] as int?;
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastPage(int bookId, int page) async {
    if (page < 1) return;
    final prefs = await SharedPreferences.getInstance();
    final uid = _uid;
    await prefs.setInt(
        uid != null ? _key(uid, bookId) : _legacyKey(bookId), page);
    // Best-effort server sync; never blocks or breaks the local save.
    unawaited(_pushToServer(bookId, page));
  }

  /// Upserts one book's progress for the current user. No-ops when signed out
  /// or offline.
  Future<void> _pushToServer(int bookId, int page) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client.from('reading_progress').upsert({
        'user_id': uid,
        'book_id': bookId,
        'last_page': page,
        'last_active_at': now,
        'updated_at': now,
      }, onConflict: 'user_id,book_id');
    } catch (_) {
      // Offline / transient error: local save already succeeded.
    }
  }

  /// One-shot reconciliation run right after login. Three steps, all
  /// best-effort and max-merged ("furthest page read" wins):
  ///   1. Migrate legacy un-namespaced keys into the current user's namespace.
  ///   2. Pull this user's server progress down into the local cache, so the
  ///      account shows its own progress even on a fresh device.
  ///   3. Push merged local values back up so the server has everything.
  Future<void> reconcileOnLogin() async {
    final uid = _uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();

    // 1. Legacy migration (pre-auth keys belong to whoever first logs in).
    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith(_prefix)) continue;
      final rest = key.substring(_prefix.length);
      if (rest.contains('_')) continue; // namespaced, not legacy
      final bookId = int.tryParse(rest);
      final page = prefs.getInt(key);
      if (bookId != null && page != null && page >= 1) {
        final nk = _key(uid, bookId);
        await prefs.setInt(nk, max(prefs.getInt(nk) ?? 0, page));
      }
      await prefs.remove(key);
    }

    // 2. Pull server → local (max-merge).
    try {
      final rows = await _client
          .from('reading_progress')
          .select('book_id, last_page')
          .eq('user_id', uid);
      for (final r in rows as List) {
        final bookId = r['book_id'] as int;
        final serverPage = (r['last_page'] as int?) ?? 1;
        final nk = _key(uid, bookId);
        await prefs.setInt(nk, max(prefs.getInt(nk) ?? 0, serverPage));
      }
    } catch (_) {
      // Offline: keep local as-is.
    }

    // 3. Push every local key for this user back up.
    final mine = '$_prefix${uid}_';
    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith(mine)) continue;
      final bookId = int.tryParse(key.substring(mine.length));
      final page = prefs.getInt(key);
      if (bookId != null && page != null && page >= 1) {
        await _pushToServer(bookId, page);
      }
    }
  }
}
