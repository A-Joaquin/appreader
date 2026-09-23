import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/auth_controller.dart';
import 'widgets/ink_cube_animation.dart';

/// Splash animado: gotas de tinta que caen dentro del cubo de la marca hasta
/// llenarlo.
///
/// El ritmo cuenta la espera real: mientras el arranque no ha resuelto la
/// sesión el cubo se llena gota a gota, y en cuanto está listo una cascada lo
/// remata. Esa resolución sale del almacenamiento local y tiene un tope de
/// tiempo en [AuthController], así que sin internet el splash tampoco se queda
/// pegado.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthController _auth = AuthController.instance;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    // Repinta con `ready` actualizado en cuanto el arranque termine.
    _auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    // Llega desde el ticker de la animación, así que navegamos al terminar el
    // frame. El router decide el destino real: la biblioteca si hay sesión
    // guardada, /login si no.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/');
    });
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: InkCubeAnimation(
        ready: !_auth.bootstrapping,
        onFilled: _leave,
      ),
    );
  }
}
