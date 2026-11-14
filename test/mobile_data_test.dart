import 'dart:async';

import 'package:blackreader/core/network/mobile_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('describeNetworkError (el motivo que ve el usuario)', () {
    test('timeout dice cuántos segundos esperó', () {
      final msg = describeNetworkError(
          TimeoutException('x', const Duration(seconds: 20)));
      expect(msg, 'el servidor no respondió en 20 s');
    });

    test('error de Supabase lleva el código', () {
      final msg = describeNetworkError(
          const PostgrestException(message: 'JWT expired', code: 'PGRST301'));
      expect(msg, contains('PGRST301'));
      expect(msg, contains('JWT expired'));
    });

    test('sin red se explica en palabras, no con la excepción cruda', () {
      final msg = describeNetworkError(
          Exception('ClientException with SocketException: Failed host lookup'));
      expect(msg, 'no hay conexión con el servidor');
    });

    test('un error desconocido largo se recorta', () {
      final msg = describeNetworkError(Exception('a' * 500));
      expect(msg.length, lessThanOrEqualTo(121));
    });
  });
}
