import 'package:flutter/foundation.dart';

import 'book_download_service.dart';

/// Lleva las descargas en curso, fuera de la pantalla que las lanzó.
///
/// Antes la descarga era un `Future` que vivía en el `State` del botón: al
/// salir de la ficha del libro el widget se destruía, el progreso dejaba de
/// pintarse y la descarga seguía a ciegas — si acababa, nadie se enteraba, y si
/// el sistema paraba la app a medias no quedaba constancia. Ahora vive aquí,
/// que es un singleton: la pantalla solo escucha y puede entrar y salir las
/// veces que haga falta.
///
/// Esto NO es descarga en segundo plano de las de verdad (con la app cerrada):
/// eso necesita un servicio en primer plano de Android (WorkManager o
/// `flutter_background_service`). Lo que cubre es todo lo demás: cambiar de
/// pantalla, volver a la biblioteca, abrir otro libro.
class DownloadManager extends ChangeNotifier {
  DownloadManager._();

  /// Instancia compartida por toda la app.
  static final DownloadManager instance = DownloadManager._();

  final Map<int, double> _progress = {};
  final Map<int, Future<void>> _running = {};
  final Map<int, Object> _errors = {};

  /// Progreso 0.0–1.0 del libro, o `null` si no hay descarga en curso.
  double? progressOf(int bookId) => _progress[bookId];

  bool isRunning(int bookId) => _running.containsKey(bookId);

  /// El error con el que terminó la última descarga de este libro, si falló.
  Object? errorOf(int bookId) => _errors[bookId];

  void clearError(int bookId) {
    if (_errors.remove(bookId) != null) notifyListeners();
  }

  /// Arranca la descarga del libro. Si ya había una en curso devuelve ESA, así
  /// que volver a entrar en la ficha y tocar el botón no la duplica.
  ///
  /// El futuro que devuelve nunca lanza: un fallo se guarda en [errorOf]. Si
  /// relanzara, una descarga que nadie está esperando (porque el usuario se
  /// fue de la pantalla) acabaría como error asíncrono sin capturar.
  Future<void> start(int bookId, BookDownloadService service) {
    final existing = _running[bookId];
    if (existing != null) return existing;

    _errors.remove(bookId);
    _progress[bookId] = 0;
    notifyListeners();

    final future = _run(bookId, service);
    _running[bookId] = future;
    return future;
  }

  Future<void> _run(int bookId, BookDownloadService service) async {
    try {
      await service.download(
        bookId,
        onProgress: (p) {
          _progress[bookId] = p;
          notifyListeners();
        },
      );
    } catch (e) {
      _errors[bookId] = e;
    } finally {
      _running.remove(bookId);
      _progress.remove(bookId);
      notifyListeners();
    }
  }

  /// Completa las imágenes que falten de un libro ya descargado (la descarga
  /// se cortó a medias, o el sistema vació la caché). Comparte el mismo carril
  /// que [start], así que la ficha lo pinta igual.
  Future<void> completeImages(int bookId, BookDownloadService service) {
    final existing = _running[bookId];
    if (existing != null) return existing;

    _errors.remove(bookId);
    _progress[bookId] = 0;
    notifyListeners();

    final future = _runImages(bookId, service);
    _running[bookId] = future;
    return future;
  }

  Future<void> _runImages(int bookId, BookDownloadService service) async {
    try {
      final missing = await service.missingImages(bookId);
      await service.cacheImages(
        missing,
        onProgress: (fraction) {
          _progress[bookId] = fraction;
          notifyListeners();
        },
      );
    } catch (e) {
      _errors[bookId] = e;
    } finally {
      _running.remove(bookId);
      _progress.remove(bookId);
      notifyListeners();
    }
  }
}
