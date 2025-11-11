import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
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
  int _failureStreak = 0;

  static const List<Duration> _retryDelays = <Duration>[
    Duration(seconds: 6),
    Duration(seconds: 20),
    Duration(minutes: 1),
  ];

  bool get isReady => _ad != null;
  bool get isLoading => _loading;

  /// Ensure an interstitial is loaded and ready soon.
  /// Safe to call repeatedly; it won't spam network requests.
  void load({required String adUnitId}) {
    if (_ad != null || _loading) {
      debugPrint('[InterstitialAdManager] Load requested but ad=${_ad != null ? "cached" : "null"}, loading=$_loading - skipping');
      return;
    }
    _adUnitId = adUnitId;
    _loading = true;
    debugPrint('[InterstitialAdManager] Loading interstitial ($adUnitId)…');
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _ad = ad..setImmersiveMode(true);
          _loading = false;
          _failureStreak = 0;
          debugPrint('[InterstitialAdManager] Interstitial cached successfully.');
        },
        onAdFailedToLoad: (LoadAdError error) {
          // Drop reference and allow a later retry
          _ad?.dispose();
          _ad = null;
          _loading = false;
          _failureStreak++;
          debugPrint('[InterstitialAdManager] Load failed (${error.code} - ${error.message}); scheduling retry.');

          final retryIndex = _failureStreak >= _retryDelays.length
              ? _retryDelays.length - 1
              : _failureStreak - 1;
          final delay = _retryDelays[retryIndex < 0 ? 0 : retryIndex];
          Future.delayed(delay, () {
            if (_ad == null && !_loading && _adUnitId == adUnitId) {
              debugPrint('[InterstitialAdManager] Retrying interstitial load…');
              load(adUnitId: adUnitId);
            }
          });
        },
      ),
    );
  }

  /// Show the interstitial if available. Completes when the ad is closed
  /// (or immediately if none available). Automatically queues the next load.
  Future<void> showIfAvailable() async {
    final ad = _ad;
    if (ad == null) {
      debugPrint('[InterstitialAdManager] showIfAvailable() called with no ready ad.');
      // Try to kick off a load for next time
      final id = _adUnitId;
      if (id != null) {
        load(adUnitId: id);
      }
      return;
    }

    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {},
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _ad = null;
        debugPrint('[InterstitialAdManager] Failed to present interstitial: ${err.message}.');
        // Immediately begin loading the next ad
        final id = _adUnitId;
        if (id != null) load(adUnitId: id);
        if (!completer.isCompleted) completer.complete();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        debugPrint('[InterstitialAdManager] Interstitial dismissed.');
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
    _failureStreak = 0;
  }
}
