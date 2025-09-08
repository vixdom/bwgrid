import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_preloadAndGo());
  }

  Future<void> _preloadAndGo() async {
    try {
      // Pre-cache splash and welcome background to avoid white flashes
      final ctx = context;
      debugPrint('[Boot] Precaching splash assets...');
      await precacheImage(const AssetImage('assets/BollyWord Splash Screen.png'), ctx);
      await precacheImage(const AssetImage('assets/BollyWord welcome screen gold.png'), ctx);
    } catch (_) {}
    // Ensure at least one frame shown before removing native splash
    await Future.delayed(const Duration(milliseconds: 50));
    FlutterNativeSplash.remove();
    if (!mounted) return;
    debugPrint('[Boot] Navigating to /splash');
    // Navigate to the Flutter SplashScreen
    Navigator.of(context).pushReplacementNamed('/splash');
  }

  @override
  Widget build(BuildContext context) {
    // This screen never shows (native splash covers it); keep it minimal.
    return const ColoredBox(color: Color(0xFF0F3460));
  }
}
