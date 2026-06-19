import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists a per-book cover override chosen by the user. The default cover is
/// resolved elsewhere (the book's `cover_url`, falling back to its first image);
/// this store only remembers an explicit choice so the user can swap it.
///
/// Stored locally in `shared_preferences`, namespaced by user id (so two
/// accounts on the same device keep separate choices) with a legacy
/// un-namespaced fallback. [revision] bumps on every change so every cover
/// widget in the app can listen and refresh at once.
class CoverStore {
  static const String _prefix = 'cover_';

  /// Bumped whenever an override is set or cleared. Cover widgets listen to it
  /// (via [ValueListenableBuilder]) to re-resolve and repaint immediately.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  String _key(int bookId) {
    final uid = _uid;
    return uid != null ? '$_prefix${uid}_$bookId' : '$_prefix$bookId';
  }

  /// The user's chosen cover URL for [bookId], or null if they haven't set one.
  Future<String?> getOverride(int bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key(bookId));
    return (value != null && value.isNotEmpty) ? value : null;
  }

  Future<void> setOverride(int bookId, String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(bookId), url);
    revision.value++;
  }

  /// Drops the override so the cover falls back to the default again.
  Future<void> clearOverride(int bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(bookId));
    revision.value++;
  }
}
