import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';
import '../constants/achievements.dart' as app;

class AchievementsService extends ChangeNotifier {
  bool _signedIn = false;

  bool get isSignedIn => _signedIn;

  Future<void> signIn() async {
    try {
      await GamesServices.signIn();
      _signedIn = true;
  notifyListeners();
    } catch (e) {
      debugPrint('Games sign-in failed: $e');
      _signedIn = false;
  notifyListeners();
    }
  }

  Future<void> showAchievements() async {
    try {
      await GamesServices.showAchievements();
    } catch (e) {
      debugPrint('Show achievements failed: $e');
    }
  }

  Future<void> unlock(app.AchievementId id) async {
  final ids = Platform.isAndroid ? app.Achievements.android : app.Achievements.ios;
    final platformId = ids[id];
    if (platformId == null) return;
    try {
      await GamesServices.unlock(achievement: Achievement(androidID: platformId, iOSID: platformId));
    } catch (e) {
      debugPrint('Unlock achievement failed for $id: $e');
    }
  }
}
