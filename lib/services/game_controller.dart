import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/feedback_settings.dart';
import 'feedback_controller.dart';
import 'achievements_service.dart';
import '../constants/achievements.dart';

/// GameController mediates gameplay events to feedback layers (sound/haptics)
/// without mixing playback code into widgets. Testable and provider-friendly.
class GameController with ChangeNotifier {
  final FeedbackSettings settings;
  final FeedbackController feedback;
  AchievementsService? achievements;
  bool _celebrated = false;

  GameController({required this.settings, required this.feedback, this.achievements});

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
  debugPrint('Playing success haptic');
  // Spec: Correct word -> success notification haptic
  await feedback.hapticSuccess();
      }
  // Achievement: first word found
  final a1 = achievements;
  if (a1 != null) {
    unawaited(a1.unlock(AchievementId.firstWord));
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
    if (_celebrated) return; // avoid multiple triggers
    _celebrated = true;
    if (settings.soundEnabled) {
      await feedback.playFireworks(maxDuration: const Duration(seconds: 7));
    }
    if (settings.hapticsEnabled) {
  // Spec: Complete -> heavyImpact (+ vibrate via controller implementation)
  await _hapticForStrength(HapticStrength.heavy);
    }
  // Achievement: first puzzle complete
  final a2 = achievements;
  if (a2 != null) {
    unawaited(a2.unlock(AchievementId.firstPuzzle));
  }
  }

  // Allow resetting celebration state when a new puzzle is loaded
  void resetCelebration() {
    _celebrated = false;
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
