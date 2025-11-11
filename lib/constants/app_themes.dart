import 'package:flutter/material.dart';

enum AppTheme { bappi, kashyap, hirani }

class AppThemes {
  static String displayName(AppTheme t) {
    switch (t) {
      case AppTheme.bappi:
        return 'Bappi';
      case AppTheme.kashyap:
        return 'Kashyap';
      case AppTheme.hirani:
        return 'Hirani';
    }
  }

  static ThemeData themeData(AppTheme t) {
    switch (t) {
      case AppTheme.bappi:
        // Golden accents on black background
        const gold = Color(0xFFFBC02D); // vivid gold
        const goldDeep = Color(0xFFFFC107);
        return ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme.dark(
            surface: Color(0xFF0B0B0B),
            onSurface: Color(0xFFFFFFFF),
            outline: Color(0xFF2A2A2A),
            primary: gold,
            onPrimary: Colors.black,
            secondary: goldDeep,
          ),
          scaffoldBackgroundColor: const Color(0xFF000000),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        );

      case AppTheme.kashyap:
        // Golden accents on black background (using Bappi's color scheme)
        const gold = Color(0xFFFBC02D); // vivid gold
        const goldDeep = Color(0xFFFFC107);
        return ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme.dark(
            surface: Color(0xFF0B0B0B),
            onSurface: Color(0xFFFFFFFF),
            outline: Color(0xFF2A2A2A),
            primary: gold,
            onPrimary: Colors.black,
            secondary: goldDeep,
          ),
          scaffoldBackgroundColor: const Color(0xFF000000),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        );

      case AppTheme.hirani:
        // Current light theme
        return ThemeData(
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
        );
    }
  }
}
