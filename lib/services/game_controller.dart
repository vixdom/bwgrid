import 'package:flutter/foundation.dart';

import '../models/feedback_settings.dart';
import 'feedback_controller.dart';

/// GameController mediates gameplay events to feedback layers (sound/haptics)
/// without mixing playback code into widgets. Testable and provider-friendly.
class GameController with ChangeNotifier {
  final FeedbackSettings settings;
  final FeedbackController feedback;

  GameController({required this.settings, required this.feedback});

  // Called when a new cell is added to the current selection path.
  Future<void> onNewCellSelected() async {
    debugPrint('onNewCellSelected - sound:${settings.soundEnabled}, haptics:${settings.hapticsEnabled}');
    try {
      if (settings.soundEnabled) {
        debugPrint('Playing tick sound');
        await feedback.playTick();
      }
      if (settings.hapticsEnabled) {
        debugPrint('Playing haptic feedback');
        await feedback.hapticSelectLetter();
      }
    } catch (e) {
      debugPrint('Error in onNewCellSelected: $e');
    }
  }

  // Call when user completes a valid word.
  Future<void> onWordFound() async {
    debugPrint('onWordFound - sound:${settings.soundEnabled}, haptics:${settings.hapticsEnabled}');
    try {
      if (settings.soundEnabled) {
        debugPrint('Playing word found sound');
        await feedback.playWordFound();
      }
      if (settings.hapticsEnabled) {
        debugPrint('Playing medium haptic');
        // Spec: Correct word -> mediumImpact
        await _hapticForStrength(HapticStrength.medium);
      }
    } catch (e) {
      debugPrint('Error in onWordFound: $e');
    }
  }

  // Call on invalid selection or submit.
  Future<void> onInvalid() async {
    debugPrint('onInvalid - sound:${settings.soundEnabled}, haptics:${settings.hapticsEnabled}');
    try {
      if (settings.soundEnabled) {
        debugPrint('Playing invalid sound');
        await feedback.playInvalid();
      }
      if (settings.hapticsEnabled) {
        debugPrint('Playing light haptic');
        // Spec: Incorrect -> lightImpact
        await _hapticForStrength(HapticStrength.light);
      }
    } catch (e) {
      debugPrint('Error in onInvalid: $e');
    }
  }

  // Call when all words are found
  Future<void> onPuzzleComplete() async {
    if (settings.soundEnabled) {
      await feedback.playFireworks();
    }
    if (settings.hapticsEnabled) {
  // Spec: Complete -> heavyImpact (+ vibrate via controller implementation)
  await _hapticForStrength(HapticStrength.heavy);
    }
  }

  Future<void> _hapticForStrength(HapticStrength strength) async {
    switch (strength) {
      case HapticStrength.light:
        await feedback.hapticLight();
        break;
      case HapticStrength.medium:
        await feedback.hapticMedium();
        break;
      case HapticStrength.heavy:
        await feedback.hapticHeavy();
        break;
    }
  }
}
