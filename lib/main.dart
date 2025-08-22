import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_themes.dart';
import 'models/feedback_settings.dart';
import 'services/feedback_controller.dart';
import 'services/game_controller.dart';
import 'services/achievements_service.dart';
import 'screens/opening_screen.dart';
import 'screens/game_screen.dart';

void main() {
  runApp(const BollyWordGridApp());
}

class BollyWordGridApp extends StatelessWidget {
  const BollyWordGridApp({super.key});

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
          GameController
        >(
          create: (ctx) => GameController(
            settings: ctx.read<FeedbackSettings>(),
            feedback: ctx.read<FeedbackController>(),
            achievements: ctx.read<AchievementsService>(),
          ),
          update: (ctx, settings, feedback, ach, gc) =>
              GameController(settings: settings, feedback: feedback, achievements: ach),
        ),
      ],
      child: Builder(builder: (context) {
        final settings = context.watch<FeedbackSettings>();
        // Silent Game Center/Play Games sign-in on startup with a non-blocking snackbar on failure
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final ach = context.read<AchievementsService>();
          if (!ach.isSignedIn) {
            await ach.signIn();
            if (!ach.isSignedIn) {
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
        // Keep a sensible dark variant for system overlays if needed (optional)
        final dark = AppThemes.themeData(AppTheme.kashyap);
        return MaterialApp(
          title: 'Bolly Word Grid',
          themeMode: ThemeMode.light,
          theme: themeData,
          darkTheme: dark,
          initialRoute: '/',
          routes: {
            '/': (context) => const OpeningScreen(),
            '/game': (context) => const GameScreen(),
          },
        );
      }),
    );
  }
}
