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
  bool _bootStarted = false;

  @override
  void initState() {
    super.initState();
    // Defer heavy work to didChangeDependencies/first frame to ensure
    // Inherited widgets like MediaQuery are available for precacheImage.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootStarted) return;
    _bootStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_preloadAndGo());
    });
  }

  Future<void> _preloadAndGo() async {
    try {
      // Start comprehensive asset preloading early
      final assetPreloader = AssetPreloader();
      debugPrint('[Boot] Starting asset preloading...');
      // Remove native splash ASAP so our full-bleed BootScreen is visible
      // immediately after the first Flutter frame.
      FlutterNativeSplash.remove();
      
      // Start preloading critical assets (non-blocking)
      final preloadFuture = assetPreloader.preloadCriticalAssets(context);
      
      // Quick preload of immediate splash assets for smooth transition
      final ctx = context;
      debugPrint('[Boot] Precaching immediate splash assets...');
      await Future.wait([
        precacheImage(const AssetImage('assets/BollyWord Splash Screen.png'), ctx),
        precacheImage(const AssetImage('assets/BollyWord welcome screen gold.png'), ctx),
      ].map((f) => f.catchError((_) {})));
      
      // Wait for critical asset preloading to complete before proceeding
      await preloadFuture;
      
    } catch (e) {
      debugPrint('[Boot] Error during preloading: $e');
    }
    
    if (!mounted) return;

    // Initialize app services
    await _initializeApp();

    if (!mounted) return;

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

      if (!mounted) return;

      debugPrint('[Boot] Connecting services...');
      // Initialize achievements service
      final achievementsService = context.read<AchievementsService>();
      if (!achievementsService.isSignedIn) {
        await achievementsService.signIn();
      }

      if (!mounted) return;

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
    // Render a full-screen splash as the very first Flutter frame to
    // complement Android 12+ native splash restrictions (center icon only).
    // This ensures a visually full-bleed splash across all platforms.
    return const Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed background image
        Image(
          image: AssetImage('assets/BollyWord Splash Screen.png'),
          fit: BoxFit.cover,
        ),
      ],
    );
  }
}
