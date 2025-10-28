import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'constants/app_themes.dart';
import 'models/feedback_settings.dart';
import 'services/feedback_controller.dart';
import 'services/game_controller.dart';
import 'services/achievements_service.dart';

import 'screens/welcome_screen.dart' as welcome;
import 'screens/game_screen.dart' as game;
import 'screens/options_screen.dart' as options;
import 'screens/splash_screen.dart' as splash;
import 'screens/boot_screen.dart' as boot;
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: WidgetsBinding.instance);
  await MobileAds.instance.initialize();
  runApp(const BollyWordGridApp());
}

class BollyWordGridApp extends StatefulWidget {
  const BollyWordGridApp({super.key});

  @override
  State<BollyWordGridApp> createState() => _BollyWordGridAppState();
}

class _BollyWordGridAppState extends State<BollyWordGridApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause music when app is backgrounded, resume when foregrounded.
    final navContext = _navigatorKey.currentContext;
    if (navContext == null) {
      return;
    }

    FeedbackController feedback;
    try {
      feedback = Provider.of<FeedbackController>(navContext, listen: false);
    } on ProviderNotFoundException {
      return;
    }
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        feedback.pauseBackgroundMusic();
        break;
      case AppLifecycleState.resumed:
        feedback.resumeBackgroundMusicIfAllowed();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FeedbackSettings()),
        ChangeNotifierProvider(create: (_) => AchievementsService()),
        ChangeNotifierProxyProvider<FeedbackSettings, FeedbackController>(
          create: (ctx) =>
              FeedbackController(ctx.read<FeedbackSettings>())..init(),
          update: (ctx, settings, controller) {
            controller ??= FeedbackController(settings);
            controller.onSettingsChanged();
            return controller;
          },
        ),
        ChangeNotifierProxyProvider3<
            FeedbackSettings,
            FeedbackController,
            AchievementsService,
            GameController>(
          create: (ctx) => GameController(
            settings: ctx.read<FeedbackSettings>(),
            feedback: ctx.read<FeedbackController>(),
            achievements: ctx.read<AchievementsService>(),
          ),
          update: (ctx, settings, feedback, ach, _) => GameController(
            settings: settings,
            feedback: feedback,
            achievements: ach,
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          final settings = context.watch<FeedbackSettings>();

          // Silent Game Center/Play Games sign-in on startup with a non-blocking snackbar on failure
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final ach = context.read<AchievementsService>();
            if (!ach.isSignedIn) {
              await ach.signIn();
              if (!ach.isSignedIn) {
                // ignore: use_build_context_synchronously
                final messenger = ScaffoldMessenger.maybeOf(context);
                messenger?.showSnackBar(
                  const SnackBar(
                    content: Text('Game Center unavailable—manage in Options.'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          });

          final themeData = AppThemes.themeData(settings.theme);
          final darkTheme = AppThemes.themeData(AppTheme.kashyap); // optional dark

          return MaterialApp(
            title: 'BollyWord Grid',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.light,
            theme: themeData,
            darkTheme: darkTheme,
            navigatorKey: _navigatorKey,
            initialRoute: '/',
            routes: {
              '/': (context) => const boot.BootScreen(),
              '/splash': (context) => splash.SplashScreen(),
              '/welcome': (context) => welcome.WelcomeScreen(),
              '/game': (context) => game.GameScreen(),
              '/options': (context) => const options.OptionsScreen(),
            },
          );
        },
      ),
    );
  }
}