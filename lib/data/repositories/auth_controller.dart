import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reading_progress_store.dart';

/// Single source of truth for the auth/session state across the app.
///
/// Listens to Supabase auth changes, keeps the current [Session] and the
/// user's `profiles.role` / `profiles.status` cached, and notifies listeners
/// (used as `go_router`'s `refreshListenable`) so the router re-evaluates
/// redirects whenever the user logs in or out.
class AuthController extends ChangeNotifier {
  AuthController._(this._client) {
    _sub = _client.auth.onAuthStateChange.listen(_onAuthChange);
  }

  /// Shared instance for the whole app.
  static final AuthController instance =
      AuthController._(Supabase.instance.client);

  final SupabaseClient _client;
  late final dynamic _sub;

  /// True until the first auth event (incl. restored session) is processed.
  /// While bootstrapping the splash stays on screen.
  bool _bootstrapping = true;
  bool get bootstrapping => _bootstrapping;

  Session? _session;
  String? _role; // 'user' | 'admin'
  String? _status; // 'active' | 'banned' | 'pending'

  bool get isLoggedIn => _session != null;
  bool get isAdmin => _role == 'admin';
  bool get isBanned => _status == 'banned';
  String? get status => _status;
  User? get user => _session?.user;

  /// Guards the one-shot local→server progress migration so it runs once per
  /// app launch (after the session is known).
  bool _syncedLocalProgress = false;

  Future<void> _onAuthChange(AuthState data) async {
    _session = data.session;
    if (_session != null) {
      await _loadProfile();
      if (!_syncedLocalProgress) {
        _syncedLocalProgress = true;
        // Best-effort: migrate legacy keys, pull this user's progress and push
        // local changes back up.
        unawaited(ReadingProgressStore().reconcileOnLogin());
      }
    } else {
      _role = null;
      _status = null;
      // Allow the next login (possibly a different account) to reconcile again.
      _syncedLocalProgress = false;
    }
    _bootstrapping = false;
    notifyListeners();
  }

  /// Caches the current user's role/status. Tolerant of transient failures:
  /// on error we simply leave the cache as-is.
  Future<void> _loadProfile() async {
    final uid = _session?.user.id;
    if (uid == null) return;
    try {
      final row = await _client
          .from('profiles')
          .select('role, status')
          .eq('id', uid)
          .maybeSingle();
      _role = row?['role'] as String?;
      _status = row?['status'] as String?;
    } catch (_) {
      // Keep whatever we had; the UI degrades to non-admin/unknown.
    }
  }

  /// Re-fetches the profile (e.g. after an admin change) and notifies.
  Future<void> refreshProfile() async {
    await _loadProfile();
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Signs up with email/password. Returns true if a session was created
  /// immediately (email confirmation disabled); false if the user must confirm
  /// their email before logging in.
  Future<bool> signUp(String email, String password,
      {String? displayName}) async {
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: displayName == null || displayName.trim().isEmpty
          ? null
          : {'display_name': displayName.trim()},
    );
    return res.session != null;
  }

  /// Re-sends the signup confirmation email.
  Future<void> resendConfirmation(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email.trim());
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
