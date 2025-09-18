import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import '../services/feedback_controller.dart';
import '../services/achievements_service.dart';
import '../services/asset_preloader.dart';

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
      // Start comprehensive asset preloading early
      final assetPreloader = AssetPreloader();
      debugPrint('[Boot] Starting asset preloading...');
      
      // Start preloading critical assets (non-blocking)
      final preloadFuture = assetPreloader.preloadCriticalAssets(context);
      
      // Quick preload of immediate splash assets for smooth transition
      final ctx = context;
      debugPrint('[Boot] Precaching immediate splash assets...');
      await Future.wait([
        precacheImage(const AssetImage('assets/BollyWord Splash Screen.png'), ctx),
        precacheImage(const AssetImage('assets/BollyWord welcome screen gold.png'), ctx),
      ].map((f) => f.catchError((_) {})));
      
      // Ensure at least one frame shown before removing native splash
      await Future.delayed(const Duration(milliseconds: 50));
      FlutterNativeSplash.remove();
      
      // Wait for critical asset preloading to complete before proceeding
      await preloadFuture;
      
    } catch (e) {
      debugPrint('[Boot] Error during preloading: $e');
    }
    
    if (!mounted) return;

    // Initialize app services
    await _initializeApp();

    debugPrint('[Boot] Navigating to /welcome');
    // Navigate directly to the Home screen
    Navigator.of(context).pushReplacementNamed('/welcome');
  }

  Future<void> _initializeApp() async {
    try {
      debugPrint('[Boot] Initializing audio...');
      // Initialize feedback controller (audio, haptics)
      final feedbackController = context.read<FeedbackController>();
      await feedbackController.init();

      debugPrint('[Boot] Connecting services...');
      // Initialize achievements service
      final achievementsService = context.read<AchievementsService>();
      if (!achievementsService.isSignedIn) {
        await achievementsService.signIn();
      }

      // Start background preloading of non-critical assets
      debugPrint('[Boot] Starting background asset preloading...');
      final assetPreloader = AssetPreloader();
      unawaited(assetPreloader.preloadNonCriticalAssets(context));

      debugPrint('[Boot] Almost ready...');
      // Small delay to ensure smooth transition
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      debugPrint('Error during app initialization: $e');
      // Continue anyway - don't let initialization errors block the app
    }
  }

  @override
  Widget build(BuildContext context) {
    // This screen never shows (native splash covers it); keep it minimal.
    return const ColoredBox(color: Color(0xFF0F3460));
  }
}
