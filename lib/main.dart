import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/feedback_settings.dart';
import 'services/feedback_controller.dart';
import 'services/game_controller.dart';
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
        ChangeNotifierProxyProvider<FeedbackSettings, FeedbackController>(
          create: (ctx) =>
              FeedbackController(ctx.read<FeedbackSettings>())..init(),
          update: (ctx, settings, controller) {
            controller ??= FeedbackController(settings);
            controller.onSettingsChanged();
            return controller;
          },
        ),
        ChangeNotifierProxyProvider2<
          FeedbackSettings,
          FeedbackController,
          GameController
        >(
          create: (ctx) => GameController(
            settings: ctx.read<FeedbackSettings>(),
            feedback: ctx.read<FeedbackController>(),
          ),
          update: (ctx, settings, feedback, gc) =>
              GameController(settings: settings, feedback: feedback),
        ),
      ],
      child: MaterialApp(
        title: 'Bolly Word Grid',
        themeMode: ThemeMode.system,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme.light(
            surface: Color(0xFFF5F5F7),
            onSurface: Color(0xFF141414),
            outline: Color(0xFFD7D7DB),
            primary: Color(0xFF6A1B9A),
            onPrimary: Colors.white,
            secondary: Color(0xFFD81B60),
          ),
          scaffoldBackgroundColor: const Color(0xFFFFFFFF),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme.dark(
            surface: Color(0xFF17171C),
            onSurface: Color(0xFFFFFFFF),
            outline: Color(0xFF2E2E36),
            primary: Color(0xFFB39DDB),
            onPrimary: Colors.black,
            secondary: Color(0xFFD81B60),
          ),
          scaffoldBackgroundColor: const Color(0xFF0E0E12),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const OpeningScreen(),
          '/game': (context) => const GameScreen(),
        },
      ),
    );
  }
}
