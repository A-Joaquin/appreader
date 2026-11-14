import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/supabase_config.dart';
import '../local/offline_cache.dart';

/// Audio en inglés de los bloques: dónde vive y cómo se guarda en el móvil.
class BlockAudio {
  BlockAudio._();

  static const String bucket = 'block-audio';

  /// Caché propia, separada de la de imágenes: la por defecto guarda como
  /// mucho 200 archivos y un libro tiene cientos o miles de bloques con audio,
  /// así que iría borrando el principio del audiolibro mientras baja el final.
  /// En la carpeta de soporte y no en la temporal, que el sistema vacía.
  static final CacheManager cache = CacheManager(
    Config(
      'blockAudio',
      stalePeriod: const Duration(days: 3650),
      maxNrOfCacheObjects: 50000,
      fileSystem: offlineFileSystem('blockAudio'),
    ),
  );

  /// URL pública del archivo (el bucket es de lectura pública). Se arma a
  /// mano, igual que `getPublicUrl`, para no depender de `Supabase.instance`:
  /// la descarga en segundo plano corre en un isolate donde no existe. Es
  /// también la clave de la caché, así que tiene que salir idéntica.
  static String urlFor(String path) =>
      '$supabaseUrl/storage/v1/object/public/$bucket/$path';
}

/// Reproductor del audio de los bloques.
///
///  - [playWord]: solo una palabra, cortada del audio del bloque (salta a su
///    inicio y para en su final; suena con la entonación de la frase).
///  - [playFrom]: el bloque desde un punto hasta el final, para leer en voz
///    alta un bloque entero o encadenar bloques.
///
/// Cada llamada corta lo que estuviera sonando.
class BlockAudioPlayer {
  BlockAudioPlayer({this.marginMs = 60});

  /// Aire alrededor de la palabra: sin él, las consonantes finales
  /// (la "s" de "bits") a veces quedan cortadas.
  final int marginMs;

  final AudioPlayer _player = AudioPlayer();
  String? _loadedPath;
  Timer? _stopTimer;

  /// Lo que espera el final de [playFrom]. Se completa con `true` si el
  /// bloque llegó al final y con `false` si lo cortó otra reproducción o
  /// [stop].
  Completer<bool>? _untilEnd;
  StreamSubscription<ProcessingState>? _endWatch;

  /// Posición actual dentro del audio cargado (interpolada por just_audio).
  int get positionMs => _player.position.inMilliseconds;

  bool get isPlaying => _player.playing;

  /// Carga [audioPath] si no es el que ya está cargado. Descargado → sale del
  /// disco sin red; si no, lo baja y lo guarda (queda para la próxima vez).
  Future<void> _load(String audioPath) async {
    if (_loadedPath == audioPath) return;
    _loadedPath = null;
    final url = BlockAudio.urlFor(audioPath);
    if (kIsWeb) {
      // En web la caché vive en memoria; el navegador ya cachea la URL.
      await _player.setUrl(url);
    } else {
      final file = await BlockAudio.cache.getSingleFile(url);
      await _player.setFilePath(file.path);
    }
    _loadedPath = audioPath;
  }

  /// Corta lo que suene y libera a quien esperaba el final de un bloque.
  Future<void> _interrupt() async {
    _stopTimer?.cancel();
    _stopTimer = null;
    await _endWatch?.cancel();
    _endWatch = null;
    final waiting = _untilEnd;
    _untilEnd = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete(false);
    await _player.pause();
  }

  Future<void> playWord(String audioPath, int startMs, int endMs) async {
    await _interrupt();
    await _load(audioPath);

    final from = startMs - marginMs < 0 ? 0 : startMs - marginMs;
    final to = endMs + marginMs;
    await _player.seek(Duration(milliseconds: from));
    unawaited(_player.play());
    // Se mira la posición cada 15 ms en vez de escuchar positionStream, que en
    // algunas plataformas llega cada ~200 ms: demasiado grueso para una
    // palabra. Tampoco vale un Timer fijo de (to - from): el audio tarda unos
    // ms en arrancar y se comería el final. `position` la interpola just_audio.
    _stopTimer = Timer.periodic(const Duration(milliseconds: 15), (timer) {
      if (_player.position.inMilliseconds >= to || !_player.playing) {
        timer.cancel();
        _player.pause();
      }
    });
  }

  /// Reproduce [audioPath] desde [fromMs] hasta el final. Devuelve `true` si
  /// llegó al final y `false` si se cortó antes ([stop] u otra reproducción).
  Future<bool> playFrom(String audioPath, int fromMs) async {
    await _interrupt();
    await _load(audioPath);
    final done = Completer<bool>();
    _untilEnd = done;
    final from = fromMs - marginMs < 0 ? 0 : fromMs - marginMs;
    await _player.seek(Duration(milliseconds: from));
    // processingStateStream repite el último estado al suscribirse: si el
    // bloque anterior acabó en `completed`, este se daría por terminado nada
    // más empezar. Solo cuenta un `completed` después de verlo activo.
    var started = false;
    _endWatch = _player.processingStateStream.listen((state) {
      if (state != ProcessingState.completed) {
        started = true;
      } else if (started && !done.isCompleted) {
        done.complete(true);
      }
    });
    unawaited(_player.play());
    final reachedEnd = await done.future;
    if (identical(_untilEnd, done)) {
      _untilEnd = null;
      await _endWatch?.cancel();
      _endWatch = null;
    }
    return reachedEnd;
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() async {
    if (_untilEnd != null) unawaited(_player.play());
  }

  Future<void> stop() => _interrupt();

  /// Deja el audio de [audioPath] en el móvil antes de que haga falta, para
  /// que el paso de un bloque al siguiente no espere a la red.
  static void prefetch(String audioPath) {
    if (kIsWeb) return;
    BlockAudio.cache
        .getSingleFile(BlockAudio.urlFor(audioPath))
        .then((_) {}, onError: (_) {});
  }

  Future<void> dispose() async {
    await _interrupt();
    await _player.dispose();
  }
}
