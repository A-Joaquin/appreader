import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'network_timeout.dart';

/// Datos móviles ("megas"): detectarlos y recordar si el usuario quiere ver
/// los libros en línea con ellos. Con datos móviles la biblioteca muestra por
/// defecto solo lo descargado y ofrece cargar en línea (una vez o siempre).
class MobileData {
  MobileData._();

  static const _prefKey = 'online_con_datos_moviles';

  /// Lo último que se detectó. Lo usa [timeout] sin tener que esperar a una
  /// nueva consulta de red en cada petición.
  static bool lastSeenMobile = false;

  /// true si el teléfono está SOLO con datos móviles (sin wifi ni cable).
  /// En la web el navegador no lo dice de forma fiable: siempre false.
  static Future<bool> isOnMobileData() async {
    if (kIsWeb) return lastSeenMobile = false;
    try {
      final r = await Connectivity().checkConnectivity();
      return lastSeenMobile = r.contains(ConnectivityResult.mobile) &&
          !r.contains(ConnectivityResult.wifi) &&
          !r.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return lastSeenMobile = false;
    }
  }

  /// ¿El usuario eligió cargar los libros en línea también con datos móviles?
  static Future<bool> isAllowed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setAllowed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  /// Tope de espera de red para este momento: con datos móviles la primera
  /// respuesta puede tardar bastante más (señal débil, la red "despertando"),
  /// así que se da más margen antes de caer a los libros descargados.
  static Duration get timeout =>
      lastSeenMobile ? kMobileNetworkTimeout : kNetworkTimeout;
}

/// Explica en palabras por qué falló una petición de red, para mostrarlo al
/// usuario en vez de caer en silencio a los libros descargados.
String describeNetworkError(Object error) {
  if (error is TimeoutException) {
    final secs = (error.duration ?? MobileData.timeout).inSeconds;
    return 'el servidor no respondió en $secs s';
  }
  if (error is PostgrestException) {
    final code = error.code ?? '';
    return 'error del servidor${code.isEmpty ? '' : ' ($code)'}: ${error.message}';
  }
  if (error is AuthException) {
    return 'problema con la sesión: ${error.message}';
  }
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup')) {
    return 'no hay conexión con el servidor';
  }
  return text.length > 120 ? '${text.substring(0, 120)}…' : text;
}
