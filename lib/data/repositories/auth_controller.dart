import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/network_timeout.dart';
import 'reading_progress_store.dart';
import 'report_store.dart';

/// Single source of truth for the auth/session state across the app.
///
/// Listens to Supabase auth changes, keeps the current [Session] and the
/// user's `profiles.role` / `profiles.status` cached, and notifies listeners
/// (used as `go_router`'s `refreshListenable`) so the router re-evaluates
/// redirects whenever the user logs in or out.
///
/// **Offline-first**: el arranque nunca depende de la red. La sesión vive en
/// el almacenamiento local del dispositivo, así que si el usuario ya entró
/// alguna vez puede seguir usando la app sin internet; el rol/estado se sirven
/// desde caché y se refrescan en segundo plano cuando hay conexión.
class AuthController extends ChangeNotifier {
  AuthController._(this._client) {
    _sub = _client.auth.onAuthStateChange.listen(
      _onAuthChange,
      // Un fallo de red al refrescar el token llega como error del stream.
      // No es motivo para cerrar sesión ni para quedarse en el splash.
      onError: (_) => _resolveBootstrap(),
    );
    // Red de seguridad: pase lo que pase con Supabase, el splash sale.
    Timer(kBootstrapTimeout, _resolveBootstrap);
  }

  /// Shared instance for the whole app.
  static final AuthController instance =
      AuthController._(Supabase.instance.client);

  static const String _rolePrefix = 'profile_role_';
  static const String _statusPrefix = 'profile_status_';

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _sub;

  /// True until the session is resolved (from local storage, not the network).
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

  /// Resuelve el arranque **sin tocar la red**: lee la sesión que Supabase ya
  /// restauró del almacenamiento local y el rol/estado cacheados de la última
  /// vez que hubo conexión. Se llama desde `main()` antes de `runApp`, así que
  /// el primer frame ya sabe si hay usuario.
  Future<void> warmUp() async {
    try {
      _session ??= _client.auth.currentSession;
      final uid = _session?.user.id;
      if (uid != null) {
        final prefs = await SharedPreferences.getInstance();
        _role = prefs.getString('$_rolePrefix$uid');
        _status = prefs.getString('$_statusPrefix$uid');
      }
    } catch (_) {
      // Sin caché seguimos: la sesión manda y el perfil se degrada a no-admin.
    } finally {
      _resolveBootstrap();
    }
  }

  /// Da por terminado el arranque (idempotente).
  void _resolveBootstrap() {
    if (!_bootstrapping) return;
    _bootstrapping = false;
    notifyListeners();
  }

  void _onAuthChange(AuthState data) {
    _session = data.session;
    if (_session != null) {
      // Importante: el perfil se pide en segundo plano. Antes se esperaba
      // aquí y, sin internet, esa petición dejaba el splash colgado.
      unawaited(_loadProfile());
      if (!_syncedLocalProgress) {
        _syncedLocalProgress = true;
        // Best-effort: migrate legacy keys, pull this user's progress and push
        // local changes back up.
        unawaited(ReadingProgressStore().reconcileOnLogin());
        // Y sube los reportes que se hicieron sin conexión.
        unawaited(ReportStore().flushPending());
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
  /// on error we simply leave the cache as-is (que es lo que permite seguir
  /// siendo admin —o no— estando sin conexión).
  Future<void> _loadProfile() async {
    final uid = _session?.user.id;
    if (uid == null) return;
    try {
      final row = await _client
          .from('profiles')
          .select('role, status')
          .eq('id', uid)
          .maybeSingle()
          .timeout(kNetworkTimeout);
      _role = row?['role'] as String?;
      _status = row?['status'] as String?;
      await _cacheProfile(uid);
      notifyListeners();
    } catch (_) {
      // Keep whatever we had; the UI degrades to non-admin/unknown.
    }
  }

  /// Guarda rol/estado para poder responder offline en el próximo arranque.
  Future<void> _cacheProfile(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = _role;
      final status = _status;
      if (role == null) {
        await prefs.remove('$_rolePrefix$uid');
      } else {
        await prefs.setString('$_rolePrefix$uid', role);
      }
      if (status == null) {
        await prefs.remove('$_statusPrefix$uid');
      } else {
        await prefs.setString('$_statusPrefix$uid', status);
      }
    } catch (_) {
      // La caché es un extra; si falla, no pasa nada.
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
    final uid = _session?.user.id;
    await _client.auth.signOut();
    if (uid != null) {
      // Que la próxima cuenta en este dispositivo no herede el rol cacheado.
      _role = null;
      _status = null;
      await _cacheProfile(uid);
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
