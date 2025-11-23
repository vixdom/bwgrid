import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'constants/app_themes.dart';
import 'models/feedback_settings.dart';
import 'services/feedback_controller.dart';
import 'services/game_controller.dart';
import 'services/achievements_service.dart';

import 'screens/welcome_screen.dart' as welcome;
import 'screens/game_screen.dart' as game;
import 'screens/options_screen.dart' as options;

// Dummy achievements service that doesn't use games_services
// Note: AchievementsService is a stubbed no-op implementation in
// services/achievements_service.dart, so we can just use it normally.

void main() {
  debugPrint("=== STARTING MAIN NO GAMES ===");
  runApp(const BollyWordGridApp());
}

class BollyWordGridApp extends StatelessWidget {
  const BollyWordGridApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint("=== BUILDING APP NO GAMES ===");
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
          debugPrint("=== BUILDING MATERIAL APP NO GAMES ===");
          final settings = context.watch<FeedbackSettings>();

          final themeData = AppThemes.themeData(settings.theme);
          final darkTheme = AppThemes.themeData(AppTheme.kashyap);

          return MaterialApp(
            title: 'BollyWord Grid - No Games',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.light,
            theme: themeData,
            darkTheme: darkTheme,
            initialRoute: '/',
            routes: {
              '/': (context) => welcome.WelcomeScreen(),
              '/game': (context) => game.GameScreen(),
              '/options': (context) => const options.OptionsScreen(),
            },
          );
        },
      ),
    );
  }
}
