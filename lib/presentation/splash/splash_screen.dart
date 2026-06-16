import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// In-app splash that shows the full branded image responsively (never
/// distorted, unlike the OS splash on Android 12+ which forces a square icon).
/// Shows briefly, then routes to the library.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const Duration _minDuration = Duration(milliseconds: 1600);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(SplashScreen._minDuration, () {
      if (mounted) context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            // Margins so the image breathes and scales down on small screens.
            padding: const EdgeInsets.all(32),
            child: Image.asset(
              'assets/branding/splash.png',
              // Responsive: fits within the available space keeping aspect
              // ratio — no squishing on any screen size or orientation.
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
