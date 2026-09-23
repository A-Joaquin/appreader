import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/network_timeout.dart';
import '../models/word_report_model.dart';

/// Envía y consulta los reportes de bloques.
///
/// Offline-first, como el resto de la app: si al reportar no hay conexión el
/// reporte se guarda en una cola local y se reintenta al volver la red (al
/// enviar el siguiente o al iniciar sesión). El usuario nunca pierde lo que
/// escribió ni ve un error por estar sin internet.
class ReportStore {
  static const String _queueKey = 'pending_word_reports';
  static const int _maxQueued = 50;

  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// Envía un reporte. Devuelve `true` si llegó al servidor y `false` si quedó
  /// en la cola local — en ambos casos el reporte está guardado.
  Future<bool> submit(WordReport report) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _client
          .from('word_reports')
          .insert(report.toInsert(uid))
          .timeout(kNetworkTimeout);
      // Aprovechamos que hay red para vaciar lo que hubiera pendiente.
      unawaited(flushPending());
      return true;
    } catch (_) {
      await _enqueue(report);
      return false;
    }
  }

  /// Reintenta los reportes que quedaron sin enviar. Best-effort: si sigue sin
  /// haber red, se quedan en la cola para la próxima.
  Future<void> flushPending() async {
    final uid = _uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final pending = _read(prefs);
    if (pending.isEmpty) return;

    final stillPending = <WordReport>[];
    for (final report in pending) {
      try {
        await _client
            .from('word_reports')
            .insert(report.toInsert(uid))
            .timeout(kNetworkTimeout);
      } catch (_) {
        // Sigue sin poder subir: lo conservamos y no insistimos con el resto.
        stillPending.add(report);
      }
    }
    await _write(prefs, stillPending);
  }

  /// Cuántos reportes esperan a tener conexión.
  Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs).length;
  }

  // --- Lectura (panel de administración) ---

  /// Todos los reportes, del más reciente al más antiguo. Solo devuelve algo
  /// para un admin (lo impone la RLS).
  Future<List<WordReport>> fetchAll() async {
    final rows = await _client
        .from('word_reports')
        .select('*')
        .order('created_at', ascending: false)
        .timeout(kNetworkTimeout);
    return (rows as List)
        .map((r) => WordReport.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Marca un reporte como resuelto (o lo reabre).
  Future<void> setResolved(int id, bool resolved) async {
    final uid = _uid;
    await _client.from('word_reports').update({
      'status': resolved ? 'resolved' : 'open',
      'resolved_at': resolved ? DateTime.now().toUtc().toIso8601String() : null,
      'resolved_by': resolved ? uid : null,
    }).eq('id', id).timeout(kNetworkTimeout);
  }

  // --- Cola local ---

  Future<void> _enqueue(WordReport report) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = _read(prefs)..add(report);
    // Tope defensivo: si alguien reporta mucho sin conexión, nos quedamos con
    // los más recientes en vez de crecer sin límite.
    if (pending.length > _maxQueued) {
      pending.removeRange(0, pending.length - _maxQueued);
    }
    await _write(prefs, pending);
  }

  List<WordReport> _read(SharedPreferences prefs) {
    final raw = prefs.getStringList(_queueKey) ?? const [];
    final out = <WordReport>[];
    for (final s in raw) {
      try {
        out.add(WordReport.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        // Entrada corrupta: se descarta.
      }
    }
    return out;
  }

  Future<void> _write(SharedPreferences prefs, List<WordReport> reports) async {
    if (reports.isEmpty) {
      await prefs.remove(_queueKey);
      return;
    }
    await prefs.setStringList(
      _queueKey,
      reports.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }
}
