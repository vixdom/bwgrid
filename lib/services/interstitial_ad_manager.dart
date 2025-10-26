import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Lightweight, reusable manager for a single InterstitialAd instance.
/// - Loads an interstitial when asked (no-op if one is already cached or loading)
/// - Shows it on demand and immediately triggers the next load after dismissal
/// - Guards against memory leaks by disposing and clearing references
class InterstitialAdManager {
  InterstitialAdManager._();
  static final InterstitialAdManager instance = InterstitialAdManager._();

  InterstitialAd? _ad;
  bool _loading = false;
  String? _adUnitId; // Remember last used ad unit for auto-reload

  bool get isReady => _ad != null;
  bool get isLoading => _loading;

  /// Ensure an interstitial is loaded and ready soon.
  /// Safe to call repeatedly; it won't spam network requests.
  void load({required String adUnitId}) {
    if (_ad != null || _loading) return;
    _adUnitId = adUnitId;
    _loading = true;
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _ad = ad..setImmersiveMode(true);
          _loading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          // Drop reference and allow a later retry
          _ad?.dispose();
          _ad = null;
          _loading = false;
        },
      ),
    );
  }

  /// Show the interstitial if available. Completes when the ad is closed
  /// (or immediately if none available). Automatically queues the next load.
  Future<void> showIfAvailable() async {
    final ad = _ad;
    if (ad == null) {
      // Try to kick off a load for next time
      final id = _adUnitId;
      if (id != null) load(adUnitId: id);
      return;
    }

    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {},
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _ad = null;
        // Immediately begin loading the next ad
        final id = _adUnitId;
        if (id != null) load(adUnitId: id);
        if (!completer.isCompleted) completer.complete();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        // Immediately begin loading the next ad
        final id = _adUnitId;
        if (id != null) load(adUnitId: id);
        if (!completer.isCompleted) completer.complete();
      },
      onAdImpression: (ad) {},
      onAdClicked: (ad) {},
    );

    // Clear cached reference before showing to avoid reuse after dismissal
    _ad = null;
    await ad.show();
    return completer.future;
  }

  /// Force drop the current ad (e.g., on app shutdown)
  Future<void> dispose() async {
    try {
      await _ad?.dispose();
    } catch (_) {}
    _ad = null;
    _loading = false;
  }
}
