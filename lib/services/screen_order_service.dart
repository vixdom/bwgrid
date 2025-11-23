import 'package:flutter/services.dart' show rootBundle;

import '../models/stage_scene.dart';

/// Loads screen ordering from a CSV asset and applies it to the stage list.
///
/// Expected CSV format (no header):
///   screen_index,screen_name,entry_key ...
/// Only the first two columns are used. Multiple rows can share the same
/// screen_index; the first occurrence determines the screen_name for that index.
class ScreenOrderService {
  static Future<List<String>> loadOrderedScreenNames(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final lines = raw.split(RegExp(r'\r?\n'));
    final Map<int, String> byIndex = {};
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(',');
      if (parts.length < 2) continue;
      final idxStr = parts[0].trim();
      final name = parts[1].trim();
      final idx = int.tryParse(idxStr);
      if (idx == null) continue;
      // Only take the first name we see for a given index
      byIndex.putIfAbsent(idx, () => name);
    }
    final ordered = byIndex.keys.toList()..sort();
    return ordered.map((k) => byIndex[k]!).toList();
  }

  /// Apply an ordered list of screen names to the base stages. Matches are
  /// done against StageDefinition.themeName (case-insensitive, trimmed).
  /// Any names not found are ignored; any base stages not referenced are
  /// appended after the ordered ones, preserving their original relative order.
  static List<StageDefinition> applyOrder(
    List<StageDefinition> base,
    List<String> orderedNames,
  ) {
    String norm(String s) => s.trim().toLowerCase();

    final Map<String, StageDefinition> byName = {
      for (final s in base) norm(s.themeName): s,
    };

    final List<StageDefinition> orderedStages = [];

    for (final name in orderedNames) {
      final key = norm(name);
      final found = byName.remove(key);
      if (found != null) {
        orderedStages.add(found);
      }
    }

    // Append remaining stages (not referenced in CSV) in their original order
    for (final s in base) {
      if (!orderedStages.contains(s)) {
        orderedStages.add(s);
      }
    }

    // Re-index sequentially starting at 1, keeping other fields unchanged
    final List<StageDefinition> reindexed = [];
    for (var i = 0; i < orderedStages.length; i++) {
      final s = orderedStages[i];
      reindexed.add(StageDefinition(
        index: i + 1,
        name: s.name,
        themeName: s.themeName,
        scenes: s.scenes,
      ));
    }
    return reindexed;
  }
}
