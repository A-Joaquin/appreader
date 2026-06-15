import 'package:flutter/material.dart';

/// The app icon (the cube), rounded.
class _Cube extends StatelessWidget {
  const _Cube({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/branding/app_icon.png',
        height: size,
        width: size,
        fit: BoxFit.cover,
        // Decode near display size to avoid loading the full-res icon.
        cacheHeight: (size * 2).round(),
      ),
    );
  }
}

/// Single-line "Black Reader" wordmark for the app bar, with the cube beside it.
///
/// The dark (white) variant is generated from the light (black) one, so both
/// share identical geometry and scale the same by height.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, this.height = 26, this.cubeSize = 22});

  final double height;
  final double cubeSize;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final asset = dark
        ? 'assets/branding/wordmark_inline_dark.png'
        : 'assets/branding/wordmark_inline_light.png';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          asset,
          height: height,
          fit: BoxFit.contain,
          // Decode a bit above display height for crisp text.
          cacheHeight: (height * 3).round(),
        ),
        const SizedBox(width: 6),
        _Cube(size: cubeSize),
      ],
    );
  }
}

/// Large "Black Reader" wordmark for big surfaces (login, etc.), with the cube
/// underneath. Also adapts to the light/dark theme.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 88, this.cubeSize = 72});

  final double height;
  final double cubeSize;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final asset = dark
        ? 'assets/branding/wordmark_dark.png'
        : 'assets/branding/wordmark_light.png';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          asset,
          height: height,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 16),
        _Cube(size: cubeSize),
      ],
    );
  }
}
