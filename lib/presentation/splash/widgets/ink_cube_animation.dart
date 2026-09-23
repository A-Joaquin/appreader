import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/theme/app_theme.dart';

/// Splash animation: tinta que cae desde el borde superior dentro del cubo de
/// la marca y lo va llenando.
///
/// Dos fases:
///  - **Goteo**: gotas sueltas, calibradas para llenar el cubo en [_dripFill]
///    (el peor caso de espera). Cada gota sube el nivel un poquito.
///  - **Cascada**: en cuanto el arranque termina ([ready]) y la marca ha estado
///    en pantalla el mínimo, el goteo se convierte en un chorro que remata el
///    llenado en [_cascade]. El cubo siempre acaba lleno antes de salir, así la
///    animación nunca se corta a medias.
class InkCubeAnimation extends StatefulWidget {
  const InkCubeAnimation({
    super.key,
    required this.ready,
    required this.onFilled,
  });

  /// El arranque ya resolvió la sesión: se puede pasar a la cascada.
  final bool ready;

  /// El cubo está lleno y la animación terminó.
  final VoidCallback onFilled;

  // --- Tiempos (segundos) ---
  /// Mínimo de goteo en pantalla antes de permitir la cascada.
  static const double _minDrip = 1.2;

  /// Lo que tarda la cascada en llenar lo que falte.
  static const double _cascade = 0.45;

  /// Respiro con el cubo lleno antes de navegar.
  static const double _hold = 0.15;

  /// Tiempo que tardaría el goteo **solo** en llenar el cubo.
  static const double _dripFill = 8.0;

  /// Cada cuánto nace una gota, y lo que tarda en caer.
  static const double _dropInterval = 0.34;
  static const double _dropFall = 0.5;

  @override
  State<InkCubeAnimation> createState() => _InkCubeAnimationState();
}

class _InkCubeAnimationState extends State<InkCubeAnimation>
    with SingleTickerProviderStateMixin {
  final _Sim _sim = _Sim();
  Ticker? _ticker;

  double _t = 0; // segundos desde que arrancó la animación
  double _lastFrame = 0;
  double _nextDropBirth = 0;
  double _target = 0; // nivel al que tiende el goteo
  double? _cascadeStart;
  double _levelAtCascade = 0;
  double? _filledAt;
  bool _done = false;
  bool _reducedMotion = false;

  /// Cuánto sube el nivel cada gota para llenar el cubo en [_dripFill].
  static const double _fillPerDrop =
      InkCubeAnimation._dropInterval / InkCubeAnimation._dripFill;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeta "reducir movimiento" del sistema: sin animación, cubo lleno.
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_ticker != null && reduced == _reducedMotion) return;
    _reducedMotion = reduced;
    if (_reducedMotion) {
      _ticker?.dispose();
      _ticker = null;
      _sim.level = 1;
      _sim.tick.value++;
      Future<void>.delayed(const Duration(milliseconds: 600), _finish);
    } else {
      _ticker ??= createTicker(_onTick)..start();
    }
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onFilled();
  }

  bool get _cascading => _cascadeStart != null;

  void _onTick(Duration elapsed) {
    _t = elapsed.inMicroseconds / 1e6;
    final dt = math.min(_t - _lastFrame, 0.05); // clamp: evita saltos feos
    _lastFrame = _t;

    // ¿Toca pasar a cascada?
    if (!_cascading && widget.ready && _t >= InkCubeAnimation._minDrip) {
      _cascadeStart = _t;
      _levelAtCascade = _sim.level;
    }

    _emitDrops();
    _advanceDrops();
    _advanceLevel(dt);
    _advanceEffects(dt);

    _sim.time = _t;
    _sim.cascade = _cascading
        ? ((_t - _cascadeStart!) / InkCubeAnimation._cascade).clamp(0.0, 1.0)
        : 0.0;
    _sim.tick.value++;

    // Lleno: un respiro y fuera.
    if (_sim.level >= 0.999) {
      _filledAt ??= _t;
      if (_t - _filledAt! >= InkCubeAnimation._hold) _finish();
    }
  }

  void _emitDrops() {
    if (_cascading) return; // la cascada sustituye al goteo
    while (_nextDropBirth <= _t) {
      _sim.drops.add(_Drop(_nextDropBirth));
      _nextDropBirth += InkCubeAnimation._dropInterval;
    }
  }

  void _advanceDrops() {
    _sim.drops.removeWhere((d) {
      if (_t < d.birth + InkCubeAnimation._dropFall) return false;
      _onImpact(fromCascade: false);
      return true;
    });
  }

  /// Onda + salpicadura al tocar la superficie.
  void _onImpact({required bool fromCascade}) {
    if (!fromCascade) _target = math.min(1.0, _target + _fillPerDrop);
    _sim.ripples.add(_Ripple(_t, fromCascade ? 0.55 : 1.0));
    final count = fromCascade ? 2 : 3;
    for (var i = 0; i < count; i++) {
      final angle = _sim.rnd.nextDouble() * math.pi; // hacia los lados/arriba
      final speed = 26 + _sim.rnd.nextDouble() * 30;
      _sim.splashes.add(_Splash(
        birth: _t,
        vx: math.cos(angle) * speed,
        vy: -math.sin(angle) * speed * 0.9 - 18,
        radius: 1.3 + _sim.rnd.nextDouble() * 1.4,
      ));
    }
  }

  void _advanceLevel(double dt) {
    if (_cascading) {
      final p =
          ((_t - _cascadeStart!) / InkCubeAnimation._cascade).clamp(0.0, 1.0);
      _sim.level = _levelAtCascade +
          (1.0 - _levelAtCascade) * Curves.easeInOutCubic.transform(p);
      // Golpeteo continuo del chorro sobre la superficie.
      if (p < 1 && _t - _sim.lastCascadeRipple > 0.09) {
        _sim.lastCascadeRipple = _t;
        _onImpact(fromCascade: true);
      }
    } else {
      // Persigue el objetivo con suavizado exponencial: el nivel nunca salta.
      _sim.level += (_target - _sim.level) * (1 - math.exp(-9 * dt));
    }
  }

  void _advanceEffects(double dt) {
    _sim.ripples.removeWhere((r) => _t - r.birth > _Ripple.life);
    for (final s in _sim.splashes) {
      s.vy += 420 * dt; // gravedad
      s.x += s.vx * dt;
      s.y += s.vy * dt;
    }
    _sim.splashes.removeWhere((s) => _t - s.birth > _Splash.life);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _sim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // El wordmark se ata a la geometría del cubo, no a la pantalla: así queda
    // siempre justo debajo y a la misma escala, lo mismo en un móvil estrecho
    // que en una ventana de escritorio ancha.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cube = _Cube(Size(constraints.maxWidth, constraints.maxHeight));
        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: CustomPaint(painter: _InkCubePainter(_sim))),
            Positioned(
              top: cube.frontBottomLeft.dy + cube.h * 0.30,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: cube.w * 1.2,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOut,
                    builder: (context, v, child) =>
                        Opacity(opacity: v, child: child),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                          AppTheme.accent, BlendMode.srcIn),
                      child: Image.asset(
                        'assets/branding/wordmark_light.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// --- Estado de la simulación: lo muta el State, lo lee el painter ---

class _Sim {
  final ValueNotifier<int> tick = ValueNotifier<int>(0);
  final math.Random rnd = math.Random(7); // semilla fija: siempre igual

  final List<_Drop> drops = [];
  final List<_Ripple> ripples = [];
  final List<_Splash> splashes = [];

  double time = 0;
  double level = 0; // 0..1 de tinta en el cubo
  double cascade = 0; // 0..1 de progreso de la cascada
  double lastCascadeRipple = -1;

  void dispose() => tick.dispose();
}

class _Drop {
  _Drop(this.birth);
  final double birth;
}

class _Ripple {
  _Ripple(this.birth, this.strength);
  static const double life = 0.75;
  final double birth;
  final double strength;
}

class _Splash {
  _Splash({
    required this.birth,
    required this.vx,
    required this.vy,
    required this.radius,
  });
  static const double life = 0.45;
  final double birth;
  final double radius;
  double x = 0;
  double y = 0;
  double vx;
  double vy;
}

// --- Geometría del cubo (proyección isométrica, caja abierta por arriba) ---

class _Cube {
  _Cube(Size size) {
    final s = math.min(size.width * 0.44, size.height * 0.24).clamp(96.0, 200.0);
    w = s;
    h = s * 0.94;
    dx = s * 0.34;
    dy = s * 0.155;

    // Centrado ópticamente: el volumen ocupa w+dx de ancho y h+dy de alto.
    final left = (size.width - (w + dx)) / 2;
    final top = (size.height * 0.46) - (h + dy) / 2;

    frontTopLeft = Offset(left, top + dy);
    frontTopRight = frontTopLeft.translate(w, 0);
    frontBottomRight = frontTopRight.translate(0, h);
    frontBottomLeft = frontTopLeft.translate(0, h);
    back = Offset(dx, -dy);
  }

  late final double w;
  late final double h;
  late final double dx;
  late final double dy;
  late final Offset frontTopLeft;
  late final Offset frontTopRight;
  late final Offset frontBottomRight;
  late final Offset frontBottomLeft;
  late final Offset back;

  Path? _mouth;
  Path? _opening;
  Path? _frontFace;
  Path? _rightFace;
  Path? _silhouette;

  /// Boca del cubo (rombo superior), borde exterior.
  Path get mouth => _mouth ??= Path()
    ..moveTo(frontTopLeft.dx, frontTopLeft.dy)
    ..lineTo(frontTopRight.dx, frontTopRight.dy)
    ..lineTo(frontTopRight.dx + back.dx, frontTopRight.dy + back.dy)
    ..lineTo(frontTopLeft.dx + back.dx, frontTopLeft.dy + back.dy)
    ..close();

  /// El hueco: la boca encogida hacia su centro deja ver el grosor de la
  /// pared, que es lo que lee el ojo como "recipiente abierto".
  Path get opening => _opening ??= _buildOpening();

  Path _buildOpening() {
    final c = Offset(frontTopLeft.dx + w / 2 + back.dx / 2,
        frontTopLeft.dy + back.dy / 2);
    const k = 0.86;
    Offset shrink(Offset p) => Offset(c.dx + (p.dx - c.dx) * k, c.dy + (p.dy - c.dy) * k);
    final a = shrink(frontTopLeft);
    final b = shrink(frontTopRight);
    final d = shrink(frontTopRight + back);
    final e = shrink(frontTopLeft + back);
    return Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(d.dx, d.dy)
      ..lineTo(e.dx, e.dy)
      ..close();
  }

  Path get frontFace => _frontFace ??= Path()
    ..addRect(Rect.fromLTWH(frontTopLeft.dx, frontTopLeft.dy, w, h));

  Path get rightFace => _rightFace ??= Path()
    ..moveTo(frontTopRight.dx, frontTopRight.dy)
    ..lineTo(frontTopRight.dx + back.dx, frontTopRight.dy + back.dy)
    ..lineTo(frontBottomRight.dx + back.dx, frontBottomRight.dy + back.dy)
    ..lineTo(frontBottomRight.dx, frontBottomRight.dy)
    ..close();

  /// Silueta completa del volumen, para recortar la tinta. Es un hexágono
  /// simple, así que se traza a mano en vez de con `Path.combine` (más barato
  /// y sin depender de operaciones booleanas de paths en web).
  Path get silhouette => _silhouette ??= (Path()
    ..moveTo(frontTopLeft.dx, frontTopLeft.dy)
    ..lineTo(frontTopLeft.dx + back.dx, frontTopLeft.dy + back.dy)
    ..lineTo(frontTopRight.dx + back.dx, frontTopRight.dy + back.dy)
    ..lineTo(frontBottomRight.dx + back.dx, frontBottomRight.dy + back.dy)
    ..lineTo(frontBottomRight.dx, frontBottomRight.dy)
    ..lineTo(frontBottomLeft.dx, frontBottomLeft.dy)
    ..close());

  /// Y de la superficie del líquido en la cara frontal, para un nivel 0..1.
  double surfaceY(double level) => frontBottomLeft.dy - h * level;

  /// Centro del rombo de la superficie: donde caen las gotas.
  Offset surfaceCenter(double level) =>
      Offset(frontTopLeft.dx + w / 2 + back.dx / 2, surfaceY(level) + back.dy / 2);
}

// --- Pintura ---

class _InkCubePainter extends CustomPainter {
  _InkCubePainter(this.sim) : super(repaint: sim.tick);

  final _Sim sim;

  static const Color _ink = AppTheme.accent; // #2B2B2B
  static const Color _bg = AppTheme.background; // #FAF8F4
  static final Color _inkDeep = Color.lerp(_ink, Colors.black, 0.45)!;
  static final Color _inkLight = Color.lerp(_ink, Colors.white, 0.26)!;

  @override
  void paint(Canvas canvas, Size size) {
    final cube = _Cube(size);
    final level = sim.level.clamp(0.0, 1.0);

    _paintEmptyCube(canvas, cube);
    _paintQuestion(canvas, cube, submerged: false, level: level);
    _paintInk(canvas, cube, level);
    _paintQuestion(canvas, cube, submerged: true, level: level);
    _paintRipples(canvas, cube, level);
    _paintOutline(canvas, cube);
    _paintCascade(canvas, cube, level);
    _paintDrops(canvas, cube, level);
    _paintSplashes(canvas, cube, level);
  }

  /// Caras vacías: relleno muy tenue para que el cubo tenga volumen sin pesar.
  void _paintEmptyCube(Canvas canvas, _Cube cube) {
    canvas.drawPath(cube.frontFace, Paint()..color = _ink.withValues(alpha: 0.05));
    canvas.drawPath(cube.rightFace, Paint()..color = _ink.withValues(alpha: 0.10));
    // Borde de la boca (el canto de la pared) y, dentro, el hueco en sombra.
    canvas.drawPath(cube.mouth, Paint()..color = _ink.withValues(alpha: 0.16));
    canvas.drawPath(cube.opening, Paint()..color = _ink.withValues(alpha: 0.30));
  }

  /// El "?" del logo en la cara frontal. Sobre la tinta se dibuja en negativo,
  /// así que al subir el nivel la interrogación se va invirtiendo.
  void _paintQuestion(
    Canvas canvas,
    _Cube cube, {
    required bool submerged,
    required double level,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          color: submerged ? _bg : _ink.withValues(alpha: 0.30),
          fontSize: cube.h * 0.56,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = Offset(
      cube.frontTopLeft.dx + (cube.w - tp.width) / 2,
      cube.frontTopLeft.dy + (cube.h - tp.height) / 2,
    );

    if (!submerged) {
      tp.paint(canvas, offset);
      return;
    }
    if (level <= 0.001) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(
      cube.frontTopLeft.dx,
      cube.surfaceY(level),
      cube.frontTopRight.dx,
      cube.frontBottomLeft.dy,
    ));
    tp.paint(canvas, offset);
    canvas.restore();
  }

  /// Desplazamiento vertical de la superficie en `x` por las ondas activas.
  double _waveAt(double x, _Cube cube) {
    var offset = 0.0;
    for (final r in sim.ripples) {
      final age = sim.time - r.birth;
      if (age < 0) continue;
      final decay = math.exp(-4.2 * age);
      final phase = (x - cube.frontTopLeft.dx) / cube.w * math.pi * 2.4;
      offset += math.sin(phase - age * 16) * cube.h * 0.022 * decay * r.strength;
    }
    return offset;
  }

  void _paintInk(Canvas canvas, _Cube cube, double level) {
    if (level <= 0.001) return;
    final surfaceY = cube.surfaceY(level);

    canvas.save();
    canvas.clipPath(cube.silhouette);

    // Cara frontal sumergida, con la arista superior ondulada.
    final front = Path()..moveTo(cube.frontTopLeft.dx, surfaceY + _waveAt(cube.frontTopLeft.dx, cube));
    const steps = 14;
    for (var i = 1; i <= steps; i++) {
      final x = cube.frontTopLeft.dx + cube.w * i / steps;
      front.lineTo(x, surfaceY + _waveAt(x, cube));
    }
    front
      ..lineTo(cube.frontBottomRight.dx, cube.frontBottomRight.dy)
      ..lineTo(cube.frontBottomLeft.dx, cube.frontBottomLeft.dy)
      ..close();
    canvas.drawPath(front, Paint()..color = _ink);

    // Cara derecha sumergida: la sombra que da el volumen.
    final right = Path()
      ..moveTo(cube.frontTopRight.dx, surfaceY + _waveAt(cube.frontTopRight.dx, cube))
      ..lineTo(cube.frontTopRight.dx + cube.back.dx, surfaceY + cube.back.dy)
      ..lineTo(cube.frontBottomRight.dx + cube.back.dx,
          cube.frontBottomRight.dy + cube.back.dy)
      ..lineTo(cube.frontBottomRight.dx, cube.frontBottomRight.dy)
      ..close();
    canvas.drawPath(right, Paint()..color = _inkDeep);

    // Superficie (rombo): el plano claro que se lee como "líquido".
    final top = Path()
      ..moveTo(cube.frontTopLeft.dx, surfaceY + _waveAt(cube.frontTopLeft.dx, cube));
    for (var i = 1; i <= steps; i++) {
      final x = cube.frontTopLeft.dx + cube.w * i / steps;
      top.lineTo(x, surfaceY + _waveAt(x, cube));
    }
    top
      ..lineTo(cube.frontTopRight.dx + cube.back.dx, surfaceY + cube.back.dy)
      ..lineTo(cube.frontTopLeft.dx + cube.back.dx, surfaceY + cube.back.dy)
      ..close();
    canvas.drawPath(top, Paint()..color = _inkLight);

    canvas.restore();
  }

  void _paintRipples(Canvas canvas, _Cube cube, double level) {
    if (sim.ripples.isEmpty || level <= 0.001) return;
    final center = cube.surfaceCenter(level);
    canvas.save();
    canvas.clipPath(cube.opening);
    for (final r in sim.ripples) {
      final age = sim.time - r.birth;
      if (age < 0) continue;
      final p = age / _Ripple.life;
      final radius = cube.w * 0.08 + cube.w * 0.42 * Curves.easeOut.transform(p);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _bg.withValues(alpha: (1 - p) * 0.5 * r.strength);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 2,
          height: radius * 2 * (cube.dy / cube.w) * 2.1,
        ),
        paint,
      );
    }
    canvas.restore();
  }

  /// Aristas por encima de todo, para que el cubo se lea siempre.
  void _paintOutline(Canvas canvas, _Cube cube) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, cube.w * 0.016)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = _ink.withValues(alpha: 0.72);

    canvas.drawPath(cube.frontFace, stroke);
    canvas.drawPath(cube.rightFace, stroke);
    canvas.drawPath(cube.mouth, stroke);
    canvas.drawPath(
      cube.opening,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, cube.w * 0.009)
        ..strokeJoin = StrokeJoin.round
        ..color = _ink.withValues(alpha: 0.45),
    );
  }

  void _paintDrops(Canvas canvas, _Cube cube, double level) {
    if (sim.drops.isEmpty) return;
    final target = cube.surfaceCenter(level);
    final paint = Paint()..color = _ink;

    for (final d in sim.drops) {
      final p = ((sim.time - d.birth) / InkCubeAnimation._dropFall).clamp(0.0, 1.0);
      // Caída libre: y ~ t². Acelera igual que una gota de verdad.
      final y = -cube.w * 0.12 + (target.dy + cube.w * 0.12) * (p * p);
      // Se estira con la velocidad (la derivada de p²), como el motion blur.
      final stretch = 1 + 2.2 * p;
      final rx = cube.w * 0.042 / (1 + 0.45 * p);
      final ry = cube.w * 0.042 * stretch;

      // Dentro del cubo se ve a través de la cara frontal: más tenue.
      final inside = y > cube.frontTopLeft.dy;
      paint.color = inside ? _ink.withValues(alpha: 0.75) : _ink;
      canvas.drawPath(_teardrop(Offset(target.dx, y), rx, ry), paint);
    }
  }

  void _paintSplashes(Canvas canvas, _Cube cube, double level) {
    if (sim.splashes.isEmpty) return;
    final center = cube.surfaceCenter(level);
    canvas.save();
    canvas.clipPath(cube.silhouette);
    for (final s in sim.splashes) {
      final p = (sim.time - s.birth) / _Splash.life;
      if (p < 0 || p > 1) continue;
      canvas.drawCircle(
        center.translate(s.x, s.y),
        s.radius * (1 - p * 0.4),
        Paint()..color = _ink.withValues(alpha: (1 - p) * 0.85),
      );
    }
    canvas.restore();
  }

  /// El chorro: entra por arriba, cae hasta la boca y se mantiene mientras
  /// dura la cascada. Los bordes ondulan para que no parezca una barra.
  void _paintCascade(Canvas canvas, _Cube cube, double level) {
    if (sim.cascade <= 0) return;

    final target = cube.surfaceCenter(level);
    // El frente del chorro cae rápido; luego el chorro queda continuo.
    final head = Curves.easeIn.transform((sim.cascade / 0.16).clamp(0.0, 1.0));
    final bottom = math.min(target.dy, -20 + (target.dy + 20) * head);
    // Se afina al final, cuando ya casi no queda por llenar.
    final fade = sim.cascade > 0.82 ? (1 - sim.cascade) / 0.18 : 1.0;
    final halfW = cube.w * 0.052 * (0.6 + 0.4 * fade);
    if (bottom <= -18 || fade <= 0) return;

    final path = Path()..moveTo(target.dx - halfW, -20);
    const steps = 22;
    for (var i = 0; i <= steps; i++) {
      final y = -20 + (bottom + 20) * i / steps;
      final wobble = math.sin(y * 0.055 + sim.time * 13) * halfW * 0.22;
      path.lineTo(target.dx - halfW + wobble, y);
    }
    for (var i = steps; i >= 0; i--) {
      final y = -20 + (bottom + 20) * i / steps;
      final wobble = math.sin(y * 0.05 - sim.time * 11) * halfW * 0.22;
      path.lineTo(target.dx + halfW + wobble, y);
    }
    path.close();

    canvas.save();
    // Dentro del cubo el chorro se ve a través del vidrio: más tenue.
    canvas.clipPath(cube.silhouette, doAntiAlias: true);
    canvas.drawPath(path, Paint()..color = _ink.withValues(alpha: 0.75));
    canvas.restore();

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, -40, 1e5, cube.frontTopLeft.dy));
    canvas.drawPath(path, Paint()..color = _ink);
    canvas.restore();
  }

  /// Gota clásica: punta arriba, panza abajo.
  Path _teardrop(Offset c, double rx, double ry) {
    return Path()
      ..moveTo(c.dx, c.dy - ry)
      ..cubicTo(c.dx + rx * 0.58, c.dy - ry * 0.42, c.dx + rx, c.dy + ry * 0.18,
          c.dx, c.dy + ry)
      ..cubicTo(c.dx - rx, c.dy + ry * 0.18, c.dx - rx * 0.58,
          c.dy - ry * 0.42, c.dx, c.dy - ry)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _InkCubePainter oldDelegate) => false;
}
