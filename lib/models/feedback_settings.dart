import 'package:flutter/foundation.dart';
import '../constants/app_themes.dart';

enum HapticStrength { light, medium, heavy }

class FeedbackSettings extends ChangeNotifier {
  bool soundEnabled;
  double volume; // 0.0 - 1.0
  bool hapticsEnabled;
  HapticStrength hapticStrength;
  bool playInSilentMode; // iOS only preference
  bool hintsEnabled;
  // Accessibility: when null, follow system. true/false overrides system.
  bool? reduceMotionOverride;
  // App theme selection
  AppTheme theme;

  FeedbackSettings({
    this.soundEnabled = true,
    this.volume = 0.35,
    this.hapticsEnabled = true,
    this.hapticStrength = HapticStrength.medium,
  this.playInSilentMode = true,
  this.hintsEnabled = true,
  this.reduceMotionOverride,
  this.theme = AppTheme.hirani,
  });

  void setSoundEnabled(bool v) {
    if (soundEnabled == v) return;
    soundEnabled = v;
    notifyListeners();
  }

  void setVolume(double v) {
    v = v.clamp(0.0, 1.0);
    if (volume == v) return;
    volume = v;
    notifyListeners();
  }

  void setHapticsEnabled(bool v) {
    if (hapticsEnabled == v) return;
    hapticsEnabled = v;
    notifyListeners();
  }

  void setHapticStrength(HapticStrength v) {
    if (hapticStrength == v) return;
    hapticStrength = v;
    notifyListeners();
  }

  void setPlayInSilentMode(bool v) {
    if (playInSilentMode == v) return;
    playInSilentMode = v;
    notifyListeners();
  }

  void setHintsEnabled(bool v) {
    if (hintsEnabled == v) return;
    hintsEnabled = v;
    notifyListeners();
  }

  void setReduceMotionOverride(bool? v) {
    if (reduceMotionOverride == v) return;
    reduceMotionOverride = v; // null means follow system
    notifyListeners();
  }

  void setTheme(AppTheme t) {
    if (theme == t) return;
    theme = t;
    notifyListeners();
  }

  void resetToDefaults() {
    soundEnabled = true;
    volume = 0.35;
    hapticsEnabled = true;
    hapticStrength = HapticStrength.medium;
    playInSilentMode = true;
    hintsEnabled = true;
    reduceMotionOverride = null;
    theme = AppTheme.hirani;
    notifyListeners();
  }
}
