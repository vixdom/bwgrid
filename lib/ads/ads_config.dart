/// Centralized AdMob configuration: app and unit IDs per platform.
/// Replace test IDs with your own before production.
class AdsConfig {
  // App IDs
  static const String androidAppId = 'ca-app-pub-4369020643957506~1567002882';
  static const String iosAppId = 'ca-app-pub-4369020643957506~1567002882';

  // Banner Ad Unit IDs
  static const String androidBanner = 'ca-app-pub-4369020643957506/1487020917';
  static const String iosBanner = 'ca-app-pub-4369020643957506/1487020917';

  // Interstitial Ad Unit IDs
  // Same unit configured for both platforms in this project; replace if you split later.
  static const String androidInterstitial = 'ca-app-pub-4369020643957506/6919642506';
  static const String iosInterstitial = 'ca-app-pub-4369020643957506/6919642506';
}
