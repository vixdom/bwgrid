import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts';
import 'package:provider/provider.dart';
import '../services/feedback_controller.dart';
import '../services/game_controller.dart';
import '../services/achievements_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String _loadingText = 'Loading...';

  @override
  void initState() {
    super.initState();
    debugPrint('[Splash] initState()');

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    _animationController.forward();

    // Precache the splash background to avoid opacity load flash
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/BollyWord Splash Screen.png'), context);
    });

    // Initialize app services during splash
    _initializeApp().then((_) {
      setState(() => _loadingText = 'Ready!');
      // Navigate to welcome screen after initialization and animation
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/welcome');
        }
      });
    });
  }

  Future<void> _initializeApp() async {
    try {
      setState(() => _loadingText = 'Initializing audio...');
      // Initialize feedback controller (audio, haptics)
      final feedbackController = context.read<FeedbackController>();
      await feedbackController.init();

      setState(() => _loadingText = 'Connecting services...');
      // Initialize achievements service
      final achievementsService = context.read<AchievementsService>();
      if (!achievementsService.isSignedIn) {
        await achievementsService.signIn();
      }

      // Begin background preloading of gameplay-critical images
      setState(() => _loadingText = 'Caching assets...');
      try {
        await Future.wait([
          // Welcome BG already cached in Boot
          precacheImage(const AssetImage('assets/images/screen_cropped.png'), context),
          precacheImage(const AssetImage('assets/BollyWord welcome screen gold.png'), context),
        ].map((f) => f.catchError((_) {})));
      } catch (_) {}

      setState(() => _loadingText = 'Almost ready...');
      // Small delay to ensure smooth transition
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('Error during app initialization: $e');
      setState(() => _loadingText = 'Loading...');
      // Continue anyway - don't let initialization errors block the app
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Splash] build()');
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background splash image
            Positioned.fill(
              child: Image.asset(
                'assets/BollyWord Splash Screen.png',
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.3),
              ),
            ),

            // Animated content
            Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App logo/icon area
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFF39C12),
                                  Color(0xFFE67E22),
                                  Color(0xFFD35400),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF39C12).withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.grid_on,
                              color: Colors.white,
                              size: 60,
                            ),
                          ),

                          const SizedBox(height: 30),

                          // App title
                          Text(
                            'BollyWord',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFamily: 'SF Pro Display',
                              shadows: [
                                Shadow(
                                  color: const Color(0xFFF39C12).withOpacity(0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Tagline
                          Text(
                            'Grid • Letters • Action!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.8),
                              letterSpacing: 1.2,
                              fontFamily: 'SF Pro Text',
                            ),
                          ),

                          const SizedBox(height: 50),

                          // Loading indicator
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFFF39C12).withOpacity(0.8),
                              ),
                              strokeWidth: 3,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Loading text
                          Text(
                            _loadingText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.6),
                              fontFamily: 'SF Pro Text',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom branding
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    '✨ Bollywood Word Search ✨',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.7),
                      fontFamily: 'SF Pro Text',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'v1.0 • 4spire',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.5),
                      fontFamily: 'SF Pro Text',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
