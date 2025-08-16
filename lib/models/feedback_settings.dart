import 'package:flutter/foundation.dart';

enum HapticStrength { light, medium, heavy }

class FeedbackSettings extends ChangeNotifier {
  bool soundEnabled;
  double volume; // 0.0 - 1.0
  bool hapticsEnabled;
  HapticStrength hapticStrength;
  bool playInSilentMode; // iOS only preference

  FeedbackSettings({
    this.soundEnabled = true,
    this.volume = 0.35,
    this.hapticsEnabled = true,
    this.hapticStrength = HapticStrength.medium,
  this.playInSilentMode = true,
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
}
