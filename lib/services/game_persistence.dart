import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/theme_dictionary.dart';

class SavedGameState {
  SavedGameState({
    required this.stageIndex,
    required this.sceneIndex,
    required this.themeName,
    required this.gridRows,
    required this.clues,
    required this.usedAnswers,
    required this.revealedClues,
    required this.foundWords,
    required this.score,
    required this.hintUnlocked,
    required this.sceneActive,
    this.remainingSeconds,
    this.sceneDurationSeconds,
    this.timeExpired = false,
    DateTime? savedAt,
  }) : savedAt = savedAt ?? DateTime.now();

  final int stageIndex;
  final int sceneIndex;
  final String themeName;
  final List<String> gridRows;
  final List<Clue> clues;
  final List<String> usedAnswers;
  final List<String> revealedClues;
  final List<String> foundWords;
  final int score;
  final bool hintUnlocked;
  final bool sceneActive;
  final int? remainingSeconds;
  final int? sceneDurationSeconds;
  final bool timeExpired;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'stageIndex': stageIndex,
        'sceneIndex': sceneIndex,
        'themeName': themeName,
        'gridRows': gridRows,
        'clues': clues
            .map((c) => {
                  'answer': c.answer,
                  'label': c.label,
                })
            .toList(),
        'usedAnswers': usedAnswers,
        'revealedClues': revealedClues,
        'foundWords': foundWords,
        'score': score,
        'hintUnlocked': hintUnlocked,
        'sceneActive': sceneActive,
        'remainingSeconds': remainingSeconds,
        'sceneDurationSeconds': sceneDurationSeconds,
        'timeExpired': timeExpired,
        'savedAt': savedAt.toIso8601String(),
        'schemaVersion': 1,
      };

  static SavedGameState? fromJson(Map<String, dynamic> json) {
    try {
      final stageIndex = json['stageIndex'] as int?;
      final sceneIndex = json['sceneIndex'] as int?;
      final themeName = json['themeName'] as String?;
      final gridRows = (json['gridRows'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[];
      final cluesJson = json['clues'] as List<dynamic>? ?? const <dynamic>[];
      final clues = cluesJson
          .map((e) => e as Map<String, dynamic>)
          .map((m) => Clue(
                answer: (m['answer'] as String).toUpperCase(),
                label: (m['label'] as String?) ?? (m['answer'] as String).toUpperCase(),
              ))
          .toList();
      final usedAnswers = (json['usedAnswers'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString().toUpperCase())
          .toList();
      final revealedClues = (json['revealedClues'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString().toUpperCase())
          .toList();
      final foundWords = (json['foundWords'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString().toUpperCase())
          .toList();
      final score = json['score'] as int? ?? 0;
      final hintUnlocked = json['hintUnlocked'] as bool? ?? false;
      final sceneActive = json['sceneActive'] as bool? ?? true;
      final remainingSeconds = json['remainingSeconds'] as int?;
      final sceneDurationSeconds = json['sceneDurationSeconds'] as int?;
      final timeExpired = json['timeExpired'] as bool? ?? false;
      final savedAtRaw = json['savedAt'] as String?;
      final savedAt = savedAtRaw != null ? DateTime.tryParse(savedAtRaw) : null;

      if (stageIndex == null || sceneIndex == null || themeName == null) {
        return null;
      }

      return SavedGameState(
        stageIndex: stageIndex,
        sceneIndex: sceneIndex,
        themeName: themeName,
        gridRows: gridRows,
        clues: clues,
        usedAnswers: usedAnswers,
        revealedClues: revealedClues,
        foundWords: foundWords,
        score: score,
        hintUnlocked: hintUnlocked,
        sceneActive: sceneActive,
        remainingSeconds: remainingSeconds,
        sceneDurationSeconds: sceneDurationSeconds,
        timeExpired: timeExpired,
        savedAt: savedAt,
      );
    } catch (e) {
      return null;
    }
  }
}

class GamePersistence {
  const GamePersistence();
  static const _kSavedGameKey = 'bwgrid_saved_game_v1';
  static const _kAllUnlockedKey = 'bwgrid_all_unlocked_v1';

  Future<void> save(SavedGameState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSavedGameKey, jsonEncode(state.toJson()));
  }

  Future<SavedGameState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSavedGameKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return SavedGameState.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear({bool resetUnlocks = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSavedGameKey);
    if (resetUnlocks) {
      await prefs.remove(_kAllUnlockedKey);
    }
  }

  Future<void> setAllScreensUnlocked(bool unlocked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAllUnlockedKey, unlocked);
  }

  Future<bool> isAllScreensUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAllUnlockedKey) ?? false;
  }
}
