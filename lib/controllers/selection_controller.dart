import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/palette.dart';

class FoundPath {
  final List<Offset> points;
  final Color color;
  final String word;
  final ValueNotifier<double> progress; // 0..1 for wipe animation
  FoundPath({
    required this.points,
    required this.color,
    required this.word,
    double initialProgress = 1.0,
  }) : progress = ValueNotifier<double>(initialProgress);
}

// Owns selection state, word-color mapping, and found paths.
class SelectionController extends ChangeNotifier {
  SelectionController({
    required List<List<String>> grid,
    required int gridSize,
    required Set<String> targetWords,
  })  : _grid = grid,
        _gridSize = gridSize,
        _targetWords = targetWords.map((e) => e.toUpperCase()).toSet() {
    _palette = List<Color>.of(kWordColors)..shuffle();
  }

  // Grid + targets
  List<List<String>> _grid;
  int _gridSize;
  Set<String> _targetWords;

  List<List<String>> get grid => _grid;
  int get gridSize => _gridSize;

  // Stable color per word
  final Map<String, Color> wordColors = <String, Color>{};
  int _nextColorIndex = 0;
  late List<Color> _palette;

  // Selection state
  List<Offset> activePath = const [];
  Color? activeColor;
  Offset? _startCell;
  Offset? _currentEndCell;

  // Persisted results
  final List<FoundPath> found = [];

  bool get hasActive => activePath.isNotEmpty;
  Set<String> get targetWords => _targetWords;
  Set<String> get remainingWords {
    final foundSet = found.map((f) => f.word).toSet();
    return _targetWords.difference(foundSet);
  }

  void resetForNewGrid({
    required List<List<String>> grid,
    required int gridSize,
    required Set<String> targetWords,
  }) {
    _grid = grid;
    _gridSize = gridSize;
    _targetWords = targetWords.map((e) => e.toUpperCase()).toSet();
  wordColors.clear();
  found.clear();
  _palette = List<Color>.of(kWordColors)..shuffle();
  _nextColorIndex = 0;
    _resetSelection();
    notifyListeners();
  }

  void restoreFoundWords(Iterable<String> words) {
    bool added = false;
    for (final raw in words) {
      final word = raw.toUpperCase();
      if (_isAlreadyFound(word)) continue;
      final path = pathForWord(word);
      if (path == null || path.isEmpty) continue;
      final assigned = wordColors[word] ?? _assignColorForWord(word);
      final fp = FoundPath(
        points: List<Offset>.unmodifiable(path),
        color: assigned,
        word: word,
        initialProgress: 1.0,
      );
      found.add(fp);
      wordColors[word] = assigned;
      added = true;
    }
    if (added) {
      notifyListeners();
    }
  }

  // Start selection
  void beginAt(Offset cell) {
  if (!_inBounds(cell)) return;
    _startCell = cell;
    _currentEndCell = cell;
    // Color: pick next from shuffled Bollywood palette if not already set
    activeColor ??= _palette[_nextColorIndex % _palette.length];
    // Begin path
    activePath = [cell];
    notifyListeners();
  }

  /// Find the starting cell (row,col) of a word in the grid using allowed directions
  /// Returns null if not found.
  Offset? findWordStart(String word) {
    final n = _gridSize;
    final w = word.toUpperCase();
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        // Right
        if (c + w.length <= n) {
          bool ok = true;
          for (int i = 0; i < w.length; i++) {
            if (_grid[r][c + i] != w[i]) { ok = false; break; }
          }
          if (ok) return Offset(r.toDouble(), c.toDouble());
        }
        // Left
        if (c - w.length + 1 >= 0) {
          bool ok = true;
          for (int i = 0; i < w.length; i++) {
            if (_grid[r][c - i] != w[i]) { ok = false; break; }
          }
          if (ok) return Offset(r.toDouble(), c.toDouble());
        }
        // Down
        if (r + w.length <= n) {
          bool ok = true;
          for (int i = 0; i < w.length; i++) {
            if (_grid[r + i][c] != w[i]) { ok = false; break; }
          }
          if (ok) return Offset(r.toDouble(), c.toDouble());
        }
        // Up
        if (r - w.length + 1 >= 0) {
          bool ok = true;
          for (int i = 0; i < w.length; i++) {
            if (_grid[r - i][c] != w[i]) { ok = false; break; }
          }
          if (ok) return Offset(r.toDouble(), c.toDouble());
        }
        // Diag down-right
        if (r + w.length <= n && c + w.length <= n) {
          bool ok = true;
          for (int i = 0; i < w.length; i++) {
            if (_grid[r + i][c + i] != w[i]) { ok = false; break; }
          }
          if (ok) return Offset(r.toDouble(), c.toDouble());
        }
        // Diag down-left (top-right to bottom-left)
        if (r + w.length <= n && c - w.length + 1 >= 0) {
          bool ok = true;
          for (int i = 0; i < w.length; i++) {
            if (_grid[r + i][c - i] != w[i]) { ok = false; break; }
          }
          if (ok) return Offset(r.toDouble(), c.toDouble());
        }
      }
    }
    return null;
  }

  List<Offset>? pathForWord(String word) {
    final target = word.toUpperCase();
    final n = _gridSize;
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (_grid[r][c] != target[0]) continue;
        final directions = <List<int>>[
          [0, 1],
          [0, -1],
          [1, 0],
          [-1, 0],
          [1, 1],
          [1, -1],
          [-1, 1],
          [-1, -1],
        ];
        for (final dir in directions) {
          final path = _collectPath(r, c, dir[0], dir[1], target);
          if (path != null) {
            return path;
          }
        }
      }
    }
    return null;
  }

  List<Offset>? _collectPath(int r, int c, int dr, int dc, String word) {
    final positions = <Offset>[];
    for (int i = 0; i < word.length; i++) {
      final rr = r + dr * i;
      final cc = c + dc * i;
      if (rr < 0 || cc < 0 || rr >= _gridSize || cc >= _gridSize) {
        return null;
      }
      if (_grid[rr][cc] != word[i]) {
        return null;
      }
      positions.add(Offset(rr.toDouble(), cc.toDouble()));
    }
    return positions;
  }

  /// Temporarily highlight a single cell as a hint
  void showHintAt(Offset cell, {int durationMs = 900}) {
    activeColor = Colors.amberAccent;
    activePath = [cell];
    notifyListeners();
    Timer(Duration(milliseconds: durationMs), () {
      activePath = const [];
      activeColor = null;
      notifyListeners();
    });
  }

  // Extend; returns true if path changed
  bool extendTo(Offset cell) {
    if (_startCell == null || !_inBounds(cell)) return false;
    // No-op if same as last point
    if (activePath.isNotEmpty && activePath.last == cell) return false;

    _currentEndCell = cell;
    final next = _linePath(_startCell!, _currentEndCell!);
    
    // For active selection, show the full path even if some cells are already found
    // The commit will validate if the selection is valid
    final changed = !_offsetListEquals(activePath, next);
    if (changed) {
      activePath = next;
      notifyListeners();
    }
    return changed;
  }

  // Finalize; returns FoundPath if a new word was found
  FoundPath? commitOrReset() {
    FoundPath? result;
    if (_startCell != null && _currentEndCell != null && activePath.isNotEmpty) {
      final selected = _wordFromPath(activePath);
      final reversed = _reverse(selected);
      final canonical = _targetWords.contains(selected)
          ? selected
          : _targetWords.contains(reversed)
              ? reversed
              : null;

      // Ignore duplicates
      if (canonical != null && !_isAlreadyFound(canonical)) {
    // Use the activeColor for this found word; also map it for chips
    final assigned = activeColor ?? (wordColors[canonical] ?? _assignColorForWord(canonical));
        final fp = FoundPath(
          points: List<Offset>.unmodifiable(activePath),
          color: assigned,
          word: canonical,
          initialProgress: 0.0,
        );
        found.add(fp);
    wordColors[canonical] = assigned;
        result = fp;
    debugPrint('commitOrReset: FOUND word=$canonical, pathLen=${activePath.length}, color=$assigned');
        // Kick off wipe animation to 1.0 over ~180ms
        _animateProgress(fp.progress, durationMs: 180);
    // Advance palette for next word
    _nextColorIndex++;
      }
    }
  // Reset active selection regardless of success
    _resetSelection();
    notifyListeners();
    return result;
  }

  /// Debug helper: force-mark a word as found by supplying its path.
  /// Returns the created [FoundPath] or null if word already recorded.
  FoundPath? forceAddWord(String word, List<Offset> path) {
    final canonical = word.toUpperCase();
    if (_isAlreadyFound(canonical)) return null;
    if (path.isEmpty) return null;
    final assigned = wordColors[canonical] ?? _assignColorForWord(canonical);
    final fp = FoundPath(
      points: List<Offset>.unmodifiable(path),
      color: assigned,
      word: canonical,
      initialProgress: 0.0,
    );
    found.add(fp);
    wordColors[canonical] = assigned;
    _animateProgress(fp.progress, durationMs: 180);
    notifyListeners();
    return fp;
  }

  // Utils

  void _resetSelection() {
    activePath = const [];
    activeColor = null;
    _startCell = null;
    _currentEndCell = null;
  }

  bool _inBounds(Offset cell) {
    final r = cell.dx.toInt();
    final c = cell.dy.toInt();
    return r >= 0 && c >= 0 && r < _gridSize && c < _gridSize;
  }

  List<Offset> _linePath(Offset start, Offset end) {
    final r0 = start.dx.toInt();
    final c0 = start.dy.toInt();
    final r1 = end.dx.toInt();
    final c1 = end.dy.toInt();
    final dr = r1 - r0;
    final dc = c1 - c0;

    if (dr == 0 && dc == 0) return [start];
    if (dr == 0) {
      final step = dc > 0 ? 1 : -1;
      return [for (int c = c0; step > 0 ? c <= c1 : c >= c1; c += step) Offset(r0.toDouble(), c.toDouble())];
    }
    if (dc == 0) {
      final step = dr > 0 ? 1 : -1;
      return [for (int r = r0; step > 0 ? r <= r1 : r >= r1; r += step) Offset(r.toDouble(), c0.toDouble())];
    }
    if (dr.abs() == dc.abs()) {
      final rs = dr > 0 ? 1 : -1;
      final cs = dc > 0 ? 1 : -1;
      return [for (int i = 0; i <= dr.abs(); i++) Offset((r0 + i * rs).toDouble(), (c0 + i * cs).toDouble())];
    }
    // Not straight
    return [start];
  }

  String _wordFromPath(List<Offset> path) {
    final b = StringBuffer();
    for (final o in path) {
      final r = o.dx.toInt();
      final c = o.dy.toInt();
      b.write(_grid[r][c]);
    }
    return b.toString().toUpperCase();
  }

  String _reverse(String s) => String.fromCharCodes(s.runes.toList().reversed);

  bool _isAlreadyFound(String word) => found.any((f) => f.word == word);

  bool _isCellInFoundPaths(Offset cell) => found.any((fp) => fp.points.contains(cell));

  Color _assignColorForWord(String word) {
    final color = _palette[_nextColorIndex % _palette.length];
    _nextColorIndex++;
    wordColors[word] = color;
    return color;
  }

  static bool _offsetListEquals(List<Offset> a, List<Offset> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Preview flash for a found word: briefly draw at high opacity
  FoundPath? getFoundByWord(String w) {
    final u = w.toUpperCase();
    try {
      return found.firstWhere((f) => f.word == u);
    } catch (_) {
      return null;
    }
  }

  void flashWord(String w) {
    final fp = getFoundByWord(w);
    if (fp == null) return;
    // Simple pulse by briefly overshooting progress and returning
    _animatePulse(fp.progress, peak: 1.05, durationMs: 180);
  }

  void _animateProgress(ValueNotifier<double> v, {required int durationMs}) {
    final int steps = (durationMs / 16).ceil();
    int i = 0;
    Timer.periodic(const Duration(milliseconds: 16), (t) {
      i++;
      final p = (i / steps).clamp(0.0, 1.0);
      v.value = Curves.easeOut.transform(p);
      notifyListeners();
      if (i >= steps) t.cancel();
    });
  }

  void _animatePulse(ValueNotifier<double> v, {double peak = 1.1, required int durationMs}) {
    final half = (durationMs / 2).round();
    final int stepsUp = (half / 16).ceil();
    final int stepsDown = stepsUp;
    int i = 0;
    // Animate up from current (assume 1.0) to peak
    Timer.periodic(const Duration(milliseconds: 16), (t) {
      i++;
      final p = (i / stepsUp).clamp(0.0, 1.0);
      final val = 1.0 + (peak - 1.0) * Curves.easeOut.transform(p);
      v.value = val;
      notifyListeners();
      if (i >= stepsUp) {
        t.cancel();
        // Animate back to 1.0
        int j = 0;
        Timer.periodic(const Duration(milliseconds: 16), (t2) {
          j++;
          final p2 = (j / stepsDown).clamp(0.0, 1.0);
          final val2 = peak - (peak - 1.0) * Curves.easeIn.transform(p2);
          v.value = val2;
          notifyListeners();
          if (j >= stepsDown) t2.cancel();
        });
      }
    });
  }
}

extension SelectionHelpers on SelectionController {
  String get activeString {
    if (activePath.isEmpty) return '';
    final b = StringBuffer();
    try {
      for (final o in activePath) {
        final r = o.dx.toInt();
        final c = o.dy.toInt();
        if (r >= 0 && r < _grid.length && c >= 0 && c < _grid[r].length) {
          b.write(_grid[r][c]);
        }
      }
      return b.toString().toUpperCase();
    } catch (e) {
      debugPrint('Error in activeString: $e');
      return '';
    }
  }

  bool get isComplete => found.length >= 10; // 10 words per puzzle

  // ...existing code...
}
