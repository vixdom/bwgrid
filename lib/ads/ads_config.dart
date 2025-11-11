import 'package:flutter/foundation.dart';

/// Centralized AdMob configuration: app and unit IDs per platform.
/// Automatically uses test IDs in debug mode, production IDs in release mode.
class AdsConfig {
  // Production App IDs
  static const String _androidAppIdProduction = 'ca-app-pub-4369020643957506~1567002882';
  static const String _iosAppIdProduction = 'ca-app-pub-4369020643957506~1567002882';

  // Test App IDs (provided by Google for testing)
  static const String _androidAppIdTest = 'ca-app-pub-3940256099942544~3347511713';
  static const String _iosAppIdTest = 'ca-app-pub-3940256099942544~1458002511';

  // App IDs - automatically switches based on build mode
  static String get androidAppId => kReleaseMode ? _androidAppIdProduction : _androidAppIdTest;
  static String get iosAppId => kReleaseMode ? _iosAppIdProduction : _iosAppIdTest;

  // Production Banner Ad Unit IDs
  static const String _androidBannerProduction = 'ca-app-pub-4369020643957506/1487020917';
  static const String _iosBannerProduction = 'ca-app-pub-4369020643957506/1487020917';

  // Test Banner Ad Unit IDs (provided by Google for testing)
  static const String _androidBannerTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerTest = 'ca-app-pub-3940256099942544/2934735716';

  // Banner Ad Unit IDs - automatically switches based on build mode
  static String get androidBanner => kReleaseMode ? _androidBannerProduction : _androidBannerTest;
  static String get iosBanner => kReleaseMode ? _iosBannerProduction : _iosBannerTest;

  // Production Interstitial Ad Unit IDs
  static const String _androidInterstitialProduction = 'ca-app-pub-4369020643957506/6919642506';
  static const String _iosInterstitialProduction = 'ca-app-pub-4369020643957506/6919642506';

  // Test Interstitial Ad Unit IDs (provided by Google for testing)
  static const String _androidInterstitialTest = 'ca-app-pub-3940256099942544/1033173712';
  static const String _iosInterstitialTest = 'ca-app-pub-3940256099942544/4411468910';

  // Interstitial Ad Unit IDs - automatically switches based on build mode
  static String get androidInterstitial => kReleaseMode ? _androidInterstitialProduction : _androidInterstitialTest;
  static String get iosInterstitial => kReleaseMode ? _iosInterstitialProduction : _iosInterstitialTest;
}
