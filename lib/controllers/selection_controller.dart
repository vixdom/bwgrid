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

  // Start selection
  void beginAt(Offset cell) {
  if (!_inBounds(cell)) return;
    _startCell = cell;
    _currentEndCell = cell;
    // Color: pick next from shuffled Bollywood palette if not already set
    activeColor ??= _palette[_nextColorIndex % _palette.length];
    // Begin path
    activePath = [cell];
    debugPrint('beginAt: active len=${activePath.length} color=$activeColor first=${activePath.isNotEmpty ? activePath.first : null}');
    notifyListeners();
  }

  // Extend; returns true if path changed
  bool extendTo(Offset cell) {
    if (_startCell == null || !_inBounds(cell)) return false;
    // No-op if same as last point
    if (activePath.isNotEmpty && activePath.last == cell) return false;
    // Only allow straight line (row/col) or perfect diagonal from the start
    final r0 = _startCell!.dx.toInt();
    final c0 = _startCell!.dy.toInt();
    final r1 = cell.dx.toInt();
    final c1 = cell.dy.toInt();
    final dr = r1 - r0;
    final dc = c1 - c0;
    final isStraightOrDiag = (dr == 0) || (dc == 0) || (dr.abs() == dc.abs());
    if (!isStraightOrDiag) return false;

    _currentEndCell = cell;
    final next = _linePath(_startCell!, _currentEndCell!);
    
    // Ensure we don't include already found cells in the active path
    final validNext = <Offset>[];
    for (final point in next) {
      validNext.add(point);
    }
    
    final changed = !_offsetListEquals(activePath, validNext);
    if (changed) {
      activePath = validNext;
      debugPrint('extendTo: active len=${activePath.length} color=$activeColor first=${activePath.isNotEmpty ? activePath.first : null}');
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

  bool _cellInAnyFound(Offset cell) {
    for (final fp in found) {
      if (fp.points.contains(cell)) return true;
    }
    return false;
  }
}
