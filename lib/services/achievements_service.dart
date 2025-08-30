import 'package:flutter/foundation.dart';
import '../constants/achievements.dart' as app;

/// No-op Achievements service to keep the app building without the
/// games_services plugin. Preserves the public API used by the app.
class AchievementsService extends ChangeNotifier {
  bool _signedIn = false;

  bool get isSignedIn => _signedIn;

  Future<void> signIn() async {
    // No-op: pretend sign-in is unavailable; keep false and notify.
    _signedIn = false;
    notifyListeners();
  }

  Future<void> showAchievements() async {
    // No-op
  }

  Future<void> unlock(app.AchievementId id) async {
    // No-op
  }
}
