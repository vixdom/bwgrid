import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import '../constants/achievements.dart' as app;

/// Achievements service backed by Apple Game Center (iOS) and Google Play Games (Android).
class AchievementsService extends ChangeNotifier {
  bool _signedIn = false;
  bool _signInInFlight = false;

  bool get isSignedIn => _signedIn;
  bool get isSigningIn => _signInInFlight;

  bool get _isPlatformSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<void> signIn({bool silent = true}) async {
    if (!_isPlatformSupported) {
      _updateSignedIn(false);
      return;
    }

    if (_signedIn || _signInInFlight) return;
    _signInInFlight = true;
    notifyListeners();

    try {
      await GamesServices.signIn();
      _updateSignedIn(true);
    } catch (err, stack) {
      if (!silent) {
        debugPrint('GamesServices.signIn failed: $err');
        debugPrint('$stack');
      }
      _updateSignedIn(false);
    } finally {
      _signInInFlight = false;
      notifyListeners();
    }
  }

  Future<void> showAchievements() async {
    if (!_isPlatformSupported) return;
    if (!_signedIn) {
      await signIn(silent: false);
      if (!_signedIn) return;
    }
    try {
      await GamesServices.showAchievements();
    } catch (err, stack) {
      debugPrint('GamesServices.showAchievements failed: $err');
      debugPrint('$stack');
    }
  }

  Future<void> unlock(app.AchievementId id) async {
    if (!_isPlatformSupported) return;

  final androidId = app.Achievements.android[id];
  final iosId = app.Achievements.ios[id];

    if (androidId == null && iosId == null) {
      debugPrint('No achievement IDs configured for $id');
      return;
    }

    if (Platform.isAndroid && androidId == null) {
      debugPrint('Missing Android achievement ID for $id');
      return;
    }

    if (Platform.isIOS && iosId == null) {
      debugPrint('Missing iOS achievement ID for $id');
      return;
    }

    if (!_signedIn) {
      await signIn();
      if (!_signedIn) return;
    }

    try {
      await GamesServices.unlock(
        achievement: Achievement(
          androidID: androidId ?? '',
          iOSID: iosId ?? '',
        ),
      );
    } catch (err, stack) {
      debugPrint('GamesServices.unlock failed for $id: $err');
      debugPrint('$stack');
    }
  }

  Future<void> resetAllAchievements() async {
    // Reset local signed-in state if needed
    _signedIn = false;
    _signInInFlight = false;
    notifyListeners();
  }

  void _updateSignedIn(bool value) {
    if (_signedIn == value) return;
    _signedIn = value;
    notifyListeners();
  }
}
