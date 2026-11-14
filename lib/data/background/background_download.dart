import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../local/app_database.dart';
import '../local/local_book_store.dart';
import '../repositories/book_download_service.dart';
import 'download_notifications.dart';

/// Qué se baja: el libro entero, las imágenes que le falten, o su audio.
enum DownloadKind {
  book('Descargando'),
  images('Completando imágenes'),
  audio('Descargando audio');

  const DownloadKind(this.label);

  /// Lo que dice la notificación mientras tanto.
  final String label;
}

/// Una descarga pendiente. Se guarda en disco (no solo en memoria) para que el
/// servicio la encuentre aunque lo haya arrancado el sistema de nuevo, y para
/// que la app, al volver a abrirse, sepa qué sigue en marcha.
class DownloadJob {
  const DownloadJob({
    required this.bookId,
    required this.kind,
    required this.title,
    required this.queuedAt,
    this.userId,
    this.accessToken,
  });

  final int bookId;
  final DownloadKind kind;

  /// Título del libro, para las notificaciones.
  final String title;
  final DateTime queuedAt;

  /// Para apuntar la descarga en `user_downloads`: en el servicio no hay
  /// sesión, así que se usa el token que tenía la app al encargarla.
  final String? userId;
  final String? accessToken;

  /// Identifica este encargo. Un libro cancelado y vuelto a pedir tiene dos
  /// encargos seguidos con la misma clave en la cola: con esto los mensajes
  /// del viejo no se confunden con el nuevo.
  int get id => queuedAt.millisecondsSinceEpoch;

  /// Una por libro, igual que en [DownloadManager]: no se encarga otra
  /// descarga del mismo libro hasta que termine la que hay.
  static String keyFor(int bookId) => '$_prefix$bookId';
  static const String _prefix = 'download_job_';

  Map<String, Object?> toJson() => {
    'bookId': bookId,
    'kind': kind.name,
    'title': title,
    'queuedAt': queuedAt.millisecondsSinceEpoch,
    'userId': userId,
    'accessToken': accessToken,
  };

  static DownloadJob? tryParse(Object? raw) {
    if (raw is! String) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return DownloadJob(
        bookId: j['bookId'] as int,
        kind: DownloadKind.values.byName(j['kind'] as String),
        title: j['title'] as String,
        queuedAt: DateTime.fromMillisecondsSinceEpoch(j['queuedAt'] as int),
        userId: j['userId'] as String?,
        accessToken: j['accessToken'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Descargas en segundo plano (solo Android).
///
/// Corren en un servicio en primer plano con su propio motor de Flutter, así
/// que siguen aunque se bloquee el móvil o se cierre la app desde recientes.
/// Mientras tanto hay una notificación fija con el progreso y un botón para
/// cancelar; al terminar, un aviso «listo para leer sin conexión» que abre la
/// ficha del libro.
///
/// La app y el servicio se hablan con mensajes: la app encarga
/// ([enqueue]) y el servicio contesta con el progreso y el resultado (ver
/// [DownloadMessage]). La cola vive en disco, así que nada se pierde si uno
/// de los dos se reinicia.
class BackgroundDownloads {
  BackgroundDownloads._();

  /// En web no hay servicios, y en iOS el sistema mata la tarea a los 30 s:
  /// allí se descarga como siempre, con la app abierta.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const int _serviceId = 4100;

  /// Nombre del `meta-data` del manifiesto con el icono de la notificación.
  static const String _iconMetaData = 'com.blackreader.download_icon';

  /// Una vez, al arrancar la app.
  static void init() {
    if (!supported) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'downloads_progress',
        channelName: 'Descargas en curso',
        channelDescription: 'Progreso de los libros que se están descargando.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        // Que siga aunque se cierre la app desde recientes, y que el sistema
        // lo vuelva a levantar si lo mata (la cola sigue en disco).
        stopWithTask: false,
        allowAutoRestart: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Pide permiso para las notificaciones (Android 13+). Si no lo da, la
  /// descarga sigue igual, solo que sin avisos.
  static Future<void> requestPermission() async {
    if (!supported) return;
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  /// Encarga [job] al servicio, arrancándolo si hace falta.
  static Future<void> enqueue(DownloadJob job) async {
    await FlutterForegroundTask.saveData(
      key: DownloadJob.keyFor(job.bookId),
      value: jsonEncode(job.toJson()),
    );
    await ensureRunning();
  }

  /// Arranca el servicio si hay algo pendiente y no está en marcha; si ya
  /// lo está, le avisa de que mire la cola.
  static Future<void> ensureRunning() async {
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask(_poke);
      return;
    }
    if ((await pendingJobs()).isEmpty) return;
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: 'BlackReader',
      notificationText: 'Preparando la descarga…',
      notificationIcon: const NotificationIcon(metaDataName: _iconMetaData),
      notificationButtons: const [
        NotificationButton(id: _cancel, text: 'Cancelar'),
      ],
      callback: backgroundDownloadCallback,
    );
    if (result is ServiceRequestFailure) throw result.error;
  }

  /// Cancela la descarga de [bookId], esté en cola o bajando.
  static Future<void> cancel(int bookId) async {
    await FlutterForegroundTask.removeData(key: DownloadJob.keyFor(bookId));
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask('$_cancel:$bookId');
    }
  }

  /// Lo que queda por bajar, en el orden en que se encargó.
  static Future<List<DownloadJob>> pendingJobs() async {
    final jobs = <DownloadJob>[];
    for (final entry in (await FlutterForegroundTask.getAllData()).entries) {
      if (!entry.key.startsWith(DownloadJob._prefix)) continue;
      final job = DownloadJob.tryParse(entry.value);
      if (job != null) jobs.add(job);
    }
    jobs.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return jobs;
  }

  static void addListener(void Function(DownloadMessage) listener) {
    _listeners.add(listener);
    if (_listeners.length == 1) {
      FlutterForegroundTask.addTaskDataCallback(_dispatch);
    }
  }

  static final List<void Function(DownloadMessage)> _listeners = [];

  static void _dispatch(Object data) {
    final message = DownloadMessage.tryParse(data);
    if (message == null) return;
    for (final listener in List.of(_listeners)) {
      listener(message);
    }
  }

  static const String _poke = 'poke';
  static const String _cancel = 'cancel';
}

/// Lo que el servicio le cuenta a la app.
class DownloadMessage {
  const DownloadMessage.progress(this.bookId, this.jobId, double this.progress)
    : done = false,
      error = null,
      cancelled = false;

  const DownloadMessage.done(
    this.bookId,
    this.jobId, {
    this.error,
    this.cancelled = false,
  }) : done = true,
       progress = null;

  final int bookId;

  /// El encargo del que habla ([DownloadJob.id]).
  final int jobId;

  /// 0.0–1.0 mientras baja.
  final double? progress;

  /// Terminó (bien, con [error] o [cancelled]).
  final bool done;
  final String? error;
  final bool cancelled;

  Map<String, Object?> toJson() => {
    'bookId': bookId,
    'jobId': jobId,
    'progress': progress,
    'done': done,
    'error': error,
    'cancelled': cancelled,
  };

  static DownloadMessage? tryParse(Object data) {
    if (data is! Map) return null;
    final bookId = data['bookId'];
    final jobId = data['jobId'];
    if (bookId is! int || jobId is! int) return null;
    if (data['done'] == true) {
      return DownloadMessage.done(
        bookId,
        jobId,
        error: data['error'] as String?,
        cancelled: data['cancelled'] == true,
      );
    }
    final progress = data['progress'];
    return progress is num
        ? DownloadMessage.progress(bookId, jobId, progress.toDouble())
        : null;
  }
}

/// Punto de entrada del servicio. Tiene que ser una función de primer nivel.
@pragma('vm:entry-point')
void backgroundDownloadCallback() {
  FlutterForegroundTask.setTaskHandler(_DownloadTaskHandler());
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// Corre dentro del servicio: va sacando descargas de la cola, una a una,
/// hasta vaciarla, y entonces para el servicio.
class _DownloadTaskHandler extends TaskHandler {
  bool _working = false;
  bool _cancelled = false;
  DownloadJob? _current;
  SupabaseClient? _client;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await DownloadNotifications.init();
    unawaited(_drain());
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  void onReceiveData(Object data) {
    if (data == BackgroundDownloads._cancel) {
      _cancelled = true;
    } else if (data is String &&
        data.startsWith('${BackgroundDownloads._cancel}:')) {
      // Si no es la que está bajando, ya se quitó de la cola y no se hará.
      final id = int.tryParse(data.split(':').last);
      if (id != null && id == _current?.bookId) _cancelled = true;
    } else {
      unawaited(_drain());
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == BackgroundDownloads._cancel) {
      _cancelled = true;
      unawaited(_cancelQueued());
    }
  }

  /// «Cancelar» en la notificación: lo que está bajando y todo lo que
  /// esperaba. A la app se le avisa de cada uno.
  Future<void> _cancelQueued() async {
    for (final job in await BackgroundDownloads.pendingJobs()) {
      await FlutterForegroundTask.removeData(
        key: DownloadJob.keyFor(job.bookId),
      );
      if (job.id != _current?.id) {
        FlutterForegroundTask.sendDataToMain(
          DownloadMessage.done(job.bookId, job.id, cancelled: true).toJson(),
        );
      }
    }
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _client?.dispose();
    _client = null;
  }

  Future<void> _drain() async {
    if (_working) return;
    _working = true;
    try {
      while (true) {
        // Se relee en cada vuelta: lo que la app encargue mientras tanto
        // entra en la cola sin tener que avisar.
        final jobs = await BackgroundDownloads.pendingJobs();
        if (jobs.isEmpty) break;
        final job = jobs.first;
        _cancelled = false;
        _current = job;
        await _run(job);
        _current = null;
        // Solo si sigue siendo ESTE encargo: si se canceló y se volvió a
        // pedir mientras bajaba, el que hay ahora es el nuevo.
        final key = DownloadJob.keyFor(job.bookId);
        final now = DownloadJob.tryParse(
          await FlutterForegroundTask.getData<String>(key: key),
        );
        if (now?.id == job.id) {
          await FlutterForegroundTask.removeData(key: key);
        }
      }
    } finally {
      _working = false;
    }
    await FlutterForegroundTask.stopService();
  }

  Future<void> _run(DownloadJob job) async {
    final client = _client ??= SupabaseClient(
      supabaseUrl,
      supabasePublishableKey,
    );
    final service = BookDownloadService(
      client,
      LocalBookStore(AppDatabase.instance),
    );

    var lastPct = -1;
    void progress(double fraction) {
      if (_cancelled) throw const _Cancelled();
      final pct = (fraction * 100).floor().clamp(0, 100);
      if (pct == lastPct) return;
      lastPct = pct;
      FlutterForegroundTask.updateService(
        notificationTitle: job.title,
        notificationText: '${job.kind.label}… $pct %',
      );
      FlutterForegroundTask.sendDataToMain(
        DownloadMessage.progress(job.bookId, job.id, fraction).toJson(),
      );
    }

    progress(0);
    try {
      final String body;
      switch (job.kind) {
        case DownloadKind.book:
          await service.download(job.bookId, onProgress: progress);
          await _report(job);
          body = _imagesBody(await service.missingImages(job.bookId));
        case DownloadKind.images:
          await service.cacheImages(
            await service.missingImages(job.bookId),
            onProgress: progress,
          );
          body = _imagesBody(await service.missingImages(job.bookId));
        case DownloadKind.audio:
          final status = await service.audioStatus(job.bookId);
          await service.cacheAudio(status.urls, onProgress: progress);
          final left = (await service.audioStatus(job.bookId)).urls.length;
          body = left == 0
              ? 'Audio en inglés listo para escuchar sin conexión.'
              : 'Audio descargado, pero ${left == 1 ? 'falta 1 bloque' : 'faltan $left bloques'}. '
                    'Vuelve a intentarlo con conexión.';
      }
      await DownloadNotifications.show(
        bookId: job.bookId,
        title: job.title,
        body: body,
      );
      FlutterForegroundTask.sendDataToMain(
        DownloadMessage.done(job.bookId, job.id).toJson(),
      );
    } on _Cancelled {
      FlutterForegroundTask.sendDataToMain(
        DownloadMessage.done(job.bookId, job.id, cancelled: true).toJson(),
      );
    } catch (e) {
      await DownloadNotifications.show(
        bookId: job.bookId,
        title: job.title,
        body:
            'No se pudo descargar. Revisa la conexión y vuelve a '
            'intentarlo desde la ficha del libro.',
      );
      FlutterForegroundTask.sendDataToMain(
        DownloadMessage.done(job.bookId, job.id, error: '$e').toJson(),
      );
    }
  }

  static String _imagesBody(List<String> missing) => missing.isEmpty
      ? 'Listo para leer sin conexión.'
      : 'Descargado, pero ${missing.length == 1 ? 'falta 1 imagen' : 'faltan ${missing.length} imágenes'}. '
            'Toca «Completar descarga» con conexión.';

  /// Apunta la descarga en el servidor con el token que tenía la app (aquí
  /// no hay sesión). Si caducó, se queda sin apuntar: es solo para el panel.
  Future<void> _report(DownloadJob job) async {
    final userId = job.userId;
    final token = job.accessToken;
    if (userId == null || token == null) return;
    final client = SupabaseClient(
      supabaseUrl,
      supabasePublishableKey,
      accessToken: () async => token,
    );
    try {
      await BookDownloadService(
        client,
        LocalBookStore(AppDatabase.instance),
      ).reportDownload(job.bookId, userId);
    } finally {
      await client.dispose();
    }
  }
}
