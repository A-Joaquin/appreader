import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../background/background_download.dart';
import 'book_download_service.dart';

/// La descarga se canceló (con el botón de la ficha o el de la notificación).
class DownloadCancelled implements Exception {
  const DownloadCancelled();

  @override
  String toString() => 'Descarga cancelada';
}

/// Lleva las descargas en curso, fuera de la pantalla que las lanzó.
///
/// Antes la descarga era un `Future` que vivía en el `State` del botón: al
/// salir de la ficha del libro el widget se destruía, el progreso dejaba de
/// pintarse y la descarga seguía a ciegas — si acababa, nadie se enteraba, y si
/// el sistema paraba la app a medias no quedaba constancia. Ahora vive aquí,
/// que es un singleton: la pantalla solo escucha y puede entrar y salir las
/// veces que haga falta.
///
/// En Android la descarga no corre aquí sino en un servicio en primer plano
/// ([BackgroundDownloads]): sigue con el móvil bloqueado o la app cerrada, y
/// avisa con una notificación al terminar. Este objeto solo la encarga y
/// escucha su progreso. En web e iOS corre aquí mismo, con la app abierta.
class DownloadManager extends ChangeNotifier {
  DownloadManager._();

  /// Instancia compartida por toda la app.
  static final DownloadManager instance = DownloadManager._();

  final Map<int, double> _progress = {};
  final Map<int, Future<void>> _running = {};
  final Map<int, Object> _errors = {};

  /// Descargas encargadas al servicio, a la espera de que diga que acabaron.
  final Map<int, Completer<void>> _waiting = {};

  /// El encargo ([DownloadJob.id]) que se sigue de cada libro. Los mensajes
  /// de otro encargo del mismo libro (uno cancelado que aún no había parado)
  /// se ignoran.
  final Map<int, int> _jobIds = {};

  /// Encargos cuya entrada ya no está en la cola pero de los que no ha
  /// llegado el «terminado». A la segunda vuelta de [_watch] se dan por
  /// cancelados (ver allí).
  final Set<int> _vanished = {};
  Timer? _watchdog;
  bool _watching = false;

  /// Progreso 0.0–1.0 del libro, o `null` si no hay descarga en curso.
  double? progressOf(int bookId) => _progress[bookId];

  bool isRunning(int bookId) => _running.containsKey(bookId);

  /// Si se puede cancelar (solo las que corren en el servicio).
  bool get canCancel => BackgroundDownloads.supported;

  /// El error con el que terminó la última descarga de este libro, si falló.
  Object? errorOf(int bookId) => _errors[bookId];

  void clearError(int bookId) {
    if (_errors.remove(bookId) != null) notifyListeners();
  }

  /// Al arrancar la app: escucha al servicio y retoma lo que siguiera en la
  /// cola (la app se cerró, o el sistema paró el servicio a medias).
  Future<void> attach() async {
    if (!BackgroundDownloads.supported) return;
    BackgroundDownloads.addListener(_onMessage);
    try {
      final pending = await BackgroundDownloads.pendingJobs();
      for (final job in pending) {
        _adopt(job.bookId, job.id);
      }
      if (pending.isNotEmpty) await BackgroundDownloads.ensureRunning();
    } catch (_) {
      // Si no arranca ahora, lo intentará el vigilante o la próxima vez.
    }
  }

  /// Arranca la descarga del libro. Si ya había una en curso devuelve ESA, así
  /// que volver a entrar en la ficha y tocar el botón no la duplica.
  ///
  /// El futuro que devuelve nunca lanza: un fallo se guarda en [errorOf]. Si
  /// relanzara, una descarga que nadie está esperando (porque el usuario se
  /// fue de la pantalla) acabaría como error asíncrono sin capturar.
  Future<void> start(
    int bookId,
    BookDownloadService service, {
    required String title,
  }) => _launch(bookId, DownloadKind.book, title, () async {
    await service.download(bookId, onProgress: (p) => _report(bookId, p));
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) await service.reportDownload(bookId, uid);
  });

  /// Completa las imágenes que falten de un libro ya descargado (la descarga
  /// se cortó a medias, o el sistema vació la caché). Comparte el mismo carril
  /// que [start], así que la ficha lo pinta igual.
  Future<void> completeImages(
    int bookId,
    BookDownloadService service, {
    required String title,
  }) => _launch(bookId, DownloadKind.images, title, () async {
    await service.cacheImages(
      await service.missingImages(bookId),
      onProgress: (p) => _report(bookId, p),
    );
  });

  /// Baja el audio en inglés que falte de un libro ya descargado. Mismo carril
  /// que [start] y [completeImages]: la ficha pinta el progreso igual.
  Future<void> downloadAudio(
    int bookId,
    BookDownloadService service, {
    required String title,
  }) => _launch(bookId, DownloadKind.audio, title, () async {
    final status = await service.audioStatus(bookId);
    await service.cacheAudio(
      status.urls,
      onProgress: (p) => _report(bookId, p),
    );
  });

  /// Cancela la descarga de [bookId] (solo en el servicio; ver [canCancel]).
  Future<void> cancel(int bookId) async {
    if (!canCancel || !isRunning(bookId)) return;
    try {
      await BackgroundDownloads.cancel(bookId);
    } catch (_) {
      // Si el servicio no contesta, ya no está bajando nada.
    }
    _finish(bookId, error: const DownloadCancelled());
  }

  Future<void> _launch(
    int bookId,
    DownloadKind kind,
    String title,
    Future<void> Function() inProcess,
  ) {
    final existing = _running[bookId];
    if (existing != null) return existing;

    _errors.remove(bookId);
    _progress[bookId] = 0;
    notifyListeners();

    final future = BackgroundDownloads.supported
        ? _runInService(bookId, kind, title)
        : _runHere(bookId, inProcess);
    _running[bookId] = future;
    return future;
  }

  Future<void> _runHere(int bookId, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      _errors[bookId] = e;
    } finally {
      _running.remove(bookId);
      _progress.remove(bookId);
      notifyListeners();
    }
  }

  Future<void> _runInService(int bookId, DownloadKind kind, String title) {
    final done = Completer<void>();
    _waiting[bookId] = done;
    () async {
      try {
        await BackgroundDownloads.requestPermission();
        final auth = Supabase.instance.client.auth;
        final job = DownloadJob(
          bookId: bookId,
          kind: kind,
          title: title,
          queuedAt: DateTime.now(),
          userId: auth.currentUser?.id,
          accessToken: auth.currentSession?.accessToken,
        );
        _jobIds[bookId] = job.id;
        await BackgroundDownloads.enqueue(job);
        _startWatchdog();
      } catch (e) {
        _finish(bookId, error: e);
      }
    }();
    return done.future;
  }

  void _report(int bookId, double progress) {
    _progress[bookId] = progress;
    notifyListeners();
  }

  /// Lo que cuenta el servicio.
  void _onMessage(DownloadMessage message) {
    final id = message.bookId;
    final tracked = _jobIds[id];
    if (tracked != null && tracked != message.jobId) return;
    if (message.done) {
      if (tracked == null) return;
      _finish(
        id,
        error: message.cancelled ? const DownloadCancelled() : message.error,
      );
      return;
    }
    // Una descarga que empezó antes de abrir la app: se adopta.
    _adopt(id, message.jobId);
    _report(id, message.progress ?? 0);
  }

  void _adopt(int bookId, int jobId) {
    if (_waiting.containsKey(bookId)) return;
    final done = Completer<void>();
    _waiting[bookId] = done;
    _running[bookId] = done.future;
    _jobIds[bookId] = jobId;
    _progress[bookId] ??= 0;
    _startWatchdog();
    notifyListeners();
  }

  void _finish(int bookId, {Object? error}) {
    if (error != null) _errors[bookId] = error;
    _running.remove(bookId);
    _progress.remove(bookId);
    _vanished.remove(bookId);
    _jobIds.remove(bookId);
    final done = _waiting.remove(bookId);
    if (done != null && !done.isCompleted) done.complete();
    if (_waiting.isEmpty) {
      _watchdog?.cancel();
      _watchdog = null;
    }
    notifyListeners();
  }

  void _startWatchdog() {
    _watchdog ??= Timer.periodic(const Duration(seconds: 5), (_) => _watch());
  }

  /// Red de seguridad por si se pierde algún mensaje del servicio: si el
  /// sistema lo paró con cosas en cola, lo vuelve a arrancar; y si un encargo
  /// desapareció de la cola sin que llegara su «terminado», lo da por
  /// cancelado a la segunda vuelta, para no adelantarse a un mensaje que
  /// todavía venía de camino.
  Future<void> _watch() async {
    if (_watching) return;
    _watching = true;
    try {
      final pending = {
        for (final job in await BackgroundDownloads.pendingJobs())
          job.bookId: job.id,
      };
      for (final id in _waiting.keys.toList()) {
        // Antes de que se guarde en la cola todavía no se sabe su id.
        final tracked = _jobIds[id];
        if (tracked == null || pending[id] == tracked) {
          _vanished.remove(id);
        } else if (!_vanished.add(id)) {
          _finish(id, error: const DownloadCancelled());
        }
      }
      if (pending.isNotEmpty && !await FlutterForegroundTask.isRunningService) {
        await BackgroundDownloads.ensureRunning();
      }
    } catch (_) {
      // Se reintenta en la próxima vuelta.
    } finally {
      _watching = false;
    }
  }
}
