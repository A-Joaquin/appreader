import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// El aviso de «libro listo» al terminar una descarga en segundo plano, y qué
/// libro abrir cuando se toca.
///
/// La notificación con el progreso es la del servicio en primer plano (ver
/// `background_download.dart`), que desaparece con él. Esta queda después,
/// así que va con `flutter_local_notifications`.
class DownloadNotifications {
  DownloadNotifications._();

  /// Icono de la barra de estado: tiene que ser blanco sobre transparente
  /// (Android pinta la silueta). `android/app/src/main/res/drawable/`.
  static const String icon = 'ic_stat_download';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'downloads_done',
      'Descargas terminadas',
      channelDescription: 'Avisa cuando un libro termina de descargarse.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: icon,
    ),
  );

  static bool _ready = false;

  /// Libro cuyo aviso se tocó y que aún no se ha abierto. Lo recoge la
  /// biblioteca: con la app cerrada, el toque llega antes de que el router
  /// haya pasado del splash.
  static final ValueNotifier<int?> pendingBook = ValueNotifier(null);

  /// [handleTaps] solo en la app (el isolate de la interfaz): el servicio de
  /// descarga solo muestra avisos, no los atiende.
  static Future<void> init({bool handleTaps = false}) async {
    // Solo Android usa las descargas en segundo plano (ver BackgroundDownloads).
    if (_ready || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(icon),
      ),
      onDidReceiveNotificationResponse: handleTaps ? _onTap : null,
    );
    _ready = true;
    if (!handleTaps) return;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
      _onTap(response);
    }
  }

  static void _onTap(NotificationResponse response) {
    final id = int.tryParse(response.payload ?? '');
    if (id != null) pendingBook.value = id;
  }

  /// Un aviso por libro: si se descarga otra vez, el nuevo sustituye al viejo.
  static Future<void> show({
    required int bookId,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      id: bookId,
      title: title,
      body: body,
      notificationDetails: _details,
      payload: '$bookId',
    );
  }
}
