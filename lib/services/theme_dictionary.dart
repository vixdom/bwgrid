import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class ThemeEntry {
  ThemeEntry({required this.name, required this.names});
  final String name;
  final List<String> names;
}

class ThemeDictionary {
  ThemeDictionary(this.themes);
  final List<ThemeEntry> themes;

  static Future<ThemeDictionary> loadFromAsset(String path) async {
    final raw = await rootBundle.loadString(path);
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final list = (decoded['themes'] as List<dynamic>).map((e) {
      final m = e as Map<String, dynamic>;
      final name = m['name'] as String? ?? 'Untitled';
      final names = (m['names'] as List<dynamic>? ?? const <dynamic>[])
          .map((x) => x.toString())
          .toList();
      return ThemeEntry(name: name, names: names);
    }).toList();
    return ThemeDictionary(list);
  }

  /// Pick a random theme that has at least [minWords] words with length <= [maxLen].
  ThemeEntry? pickRandom(int minWords, {required int maxLen}) {
    final candidates = themes.where((t) {
      final usable = t.names.map(_sanitize).where((w) => w.length <= maxLen && w.length >= 3 && w.length < maxLen).toSet();
      return usable.length >= minWords;
    }).toList();
    if (candidates.isEmpty) return null;
    candidates.shuffle();
    return candidates.first;
  }

  ThemeEntry findByName(String name) {
    final target = name.trim().toLowerCase();
    return themes.firstWhere(
      (t) => t.name.trim().toLowerCase() == target,
      orElse: () => themes.isNotEmpty ? themes.first : ThemeEntry(name: 'Default', names: const []),
    );
  }
}

String _sanitize(String s) {
  final up = s.toUpperCase();
  final lettersOnly = up.replaceAll(RegExp(r'[^A-Z]'), '');
  return lettersOnly;
}

class Clue {
  final String answer; // sanitized A-Z only
  final String label;  // human-friendly with spaces
  Clue({required this.answer, required this.label});
}

String _labelize(String original) {
  // Insert spaces between camel-case boundaries, preserve existing spaces, drop non-letters except spaces
  // Then uppercase for display consistency.
  final withSpaces = original.replaceAllMapped(
    RegExp(r'(?<=[a-z])(?=[A-Z])'),
    (m) => ' ',
  );
  final cleaned = withSpaces.replaceAll(RegExp(r'[^A-Za-z ]'), ' ');
  final squashed = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  return squashed.toUpperCase();
}

extension ThemeEntryHelpers on ThemeEntry {
  /// Return up to [count] unique, sanitized words (A-Z only), max length [maxLen].
  List<String> pickWords(int count, {required int maxLen}) {
    final pool = names.map(_sanitize).where((w) => w.length < maxLen && w.length >= 3).toSet().toList();
    pool.shuffle();
    return pool.take(count).toList();
  }

  /// Return up to [count] unique clues with spaced labels for readability and sanitized answers for grid.
  List<Clue> pickClues(int count, {required int maxLen, Set<String> exclude = const <String>{}}) {
    final exclusion = exclude.map((e) => e.toUpperCase()).toSet();
    final unique = <String, Clue>{};
    for (final n in names) {
      final ans = _sanitize(n);
      if (ans.length >= 3 && ans.length < maxLen && !exclusion.contains(ans)) {
        unique[ans] = Clue(answer: ans, label: _labelize(n));
      }
    }
    final list = unique.values.toList();
    list.shuffle();
    return list.take(count).toList();
  }
}
