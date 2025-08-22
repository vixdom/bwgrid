import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import '../services/game_controller.dart';
import '../controllers/selection_controller.dart';
import '../widgets/film_reel_painter.dart';
import '../services/theme_dictionary.dart';
import '../models/feedback_settings.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Helper to verify word is present in grid in allowed directions
  bool _isWordInGrid(List<List<String>> grid, String word) {
    final n = grid.length;
    word = word.toUpperCase();
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        // Check right
        if (c + word.length <= n) {
          bool match = true;
          for (int i = 0; i < word.length; i++) {
            if (grid[r][c + i] != word[i]) {
              match = false;
              break;
            }
          }
          if (match) return true;
        }
        // Check left
        if (c - word.length + 1 >= 0) {
          bool match = true;
          for (int i = 0; i < word.length; i++) {
            if (grid[r][c - i] != word[i]) {
              match = false;
              break;
            }
          }
          if (match) return true;
        }
        // Check down
        if (r + word.length <= n) {
          bool match = true;
          for (int i = 0; i < word.length; i++) {
            if (grid[r + i][c] != word[i]) {
              match = false;
              break;
            }
          }
          if (match) return true;
        }
        // Check up
        if (r - word.length + 1 >= 0) {
          bool match = true;
          for (int i = 0; i < word.length; i++) {
            if (grid[r - i][c] != word[i]) {
              match = false;
              break;
            }
          }
          if (match) return true;
        }
        // Check diag down-right
        if (r + word.length <= n && c + word.length <= n) {
          bool match = true;
          for (int i = 0; i < word.length; i++) {
            if (grid[r + i][c + i] != word[i]) {
              match = false;
              break;
            }
          }
          if (match) return true;
        }
        // Check diag down-left (top-right to bottom-left)
        if (r + word.length <= n && c - word.length + 1 >= 0) {
          bool match = true;
          for (int i = 0; i < word.length; i++) {
            if (grid[r + i][c - i] != word[i]) {
              match = false;
              break;
            }
          }
          if (match) return true;
        }
      }
    }
    return false;
  }
  static const int gridSize = 12;
  List<List<String>>? grid;
  SelectionController? _sel;
  bool _showConfetti = false;
  List<_ConfettiDot> _confetti = const [];
  String _themeTitle = '';
  List<Clue> _clues = const [];
  bool _startingNewPuzzle = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPuzzle());
  }

  // Removed unused legacy _onPanUpdate

  // Grid-local gesture mapping using inner constraints
  void _onGridPanStart(DragStartDetails details, BoxConstraints inner) {
    if (_sel == null) return;
    final cell = inner.maxWidth / gridSize;
    final col = (details.localPosition.dx / cell).floor();
    final row = (details.localPosition.dy / cell).floor();
    if (row >= 0 && row < gridSize && col >= 0 && col < gridSize) {
      setState(() {
        _sel!.beginAt(Offset(row.toDouble(), col.toDouble()));
      });
      // Play tick sound for the first letter
      final gameController = context.read<GameController>();
      unawaited(gameController.onNewCellSelected());
      debugPrint('Pan started at row: $row, col: $col');
    }
  }

  void _onGridPanUpdate(DragUpdateDetails details, BoxConstraints inner) {
    if (_sel == null || !_sel!.hasActive) return;
    final cell = inner.maxWidth / gridSize;
    final col = (details.localPosition.dx / cell).floor();
    final row = (details.localPosition.dy / cell).floor();
    
    if (row >= 0 && row < gridSize && col >= 0 && col < gridSize) {
      final currentCell = Offset(row.toDouble(), col.toDouble());
      // Only play sound if we moved to a new cell
      if (_sel!.activePath.isEmpty || _sel!.activePath.last != currentCell) {
        final changed = _sel!.extendTo(currentCell);
        if (changed) {
          setState(() {}); // Update the UI
          // Play tick sound for each new cell
          final gameController = context.read<GameController>();
          unawaited(gameController.onNewCellSelected());
        }
      }
    }
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    // Capture selection state before it gets reset inside commitOrReset
    final wasActive = _sel?.hasActive == true;
    final prevLen = _sel?.activePath.length ?? 0;
    final found = _sel?.commitOrReset();
    final gc = context.read<GameController>();
    
    // Always hide the preview when the user lifts their finger
    setState(() {
      // The preview will be hidden automatically because _sel.hasActive will be false after commitOrReset
    });
    
  if (found != null) {
      debugPrint('Word found: ${found.word}');
      // Scoring: +10 per correct word
      setState(() => score += 10);
      await gc.onWordFound();
      debugPrint('After onWordFound');
      // Check hint unlock at 20 points and play a pop/clue sound once
      if (!_hintUnlocked && score >= 20) {
        _hintUnlocked = true;
        unawaited(gc.feedback.playClue());
      }
      
      // Accessibility announce
      // ignore: use_build_context_synchronously
      SemanticsService.announce(
        'Found ${found.word}. ${_sel?.found.length ?? 0} of 10 words.',
        TextDirection.ltr,
      );
      
      if (_sel?.isComplete == true) {
        debugPrint('Puzzle complete!');
        await gc.onPuzzleComplete();
        _spawnConfetti();
      }
    } else if (wasActive && prevLen >= 2) {
      // Only play invalid sound if there was a meaningful selection before reset
      debugPrint('Playing invalid selection sound');
      await gc.onInvalid();
    }
  }

  // Word found / invalid triggers would be called from validation logic
  // using GameController.onWordFound() / onInvalid().

  bool _isInFoundPaths(Offset cell, SelectionController sc) {
    for (final fp in sc.found) {
      for (final o in fp.points) {
        if (o == cell) return true;
      }
    }
    return false;
  }

  // Removed unused _randomColor()

  // Score
  int score = 0;
  bool _hintUnlocked = false;

  Future<void> _loadPuzzle() async {
    // Load theme dictionary
    final dict = await ThemeDictionary.loadFromAsset(
      'assets/key and themes.txt',
    );
    final picked = dict.pickRandom(10, maxLen: gridSize);
    // Fallback in the unlikely case pickRandom returns null
    final theme =
        picked ??
        (dict.themes.isNotEmpty
            ? dict.themes.first
            : ThemeEntry(name: 'Bolly Words', names: const []));
  final clues = theme.pickClues(10, maxLen: gridSize);
    // Ensure exactly 10
    final chosen = (clues.length >= 10)
        ? clues.take(10).toList()
        : (clues +
                  List<Clue>.generate(
                    10 - clues.length,
                    (i) =>
                        Clue(answer: 'BOLLY${i + 1}', label: 'BOLLY ${i + 1}'),
                  ))
              .take(10)
              .toList();

    // Show names immediately
    setState(() {
      _themeTitle = theme.name.toUpperCase();
      _clues = List<Clue>.from(chosen);
      grid = null;
      _sel = null;
    });

    // Generate until all 10 names are placed per rules
    const int maxAttempts = 1000;
    _Puzzle? puzzle;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final candidate = _generateConstrainedPuzzle(
        gridSize,
        chosen.map((c) => c.answer).toList(),
      );
      if (candidate == null) continue;
      final ok = chosen.every((clue) => _isWordInGrid(candidate.grid, clue.answer));
      if (ok) {
        puzzle = candidate;
        break;
      }
    }

    if (puzzle == null) {
      // As a last resort, keep showing names and a message; avoid showing a bogus grid
      debugPrint('Failed to generate a valid puzzle after $maxAttempts attempts');
      return;
    }

    final p = puzzle; // non-null
    setState(() {
      grid = p.grid;
      _sel = SelectionController(
        grid: grid!,
        gridSize: gridSize,
        targetWords: p.words.toSet(),
      );
    });
  // Reset completion celebration state for the new puzzle
  context.read<GameController>().resetCelebration();
  }

  Future<void> _playAgain() async {
    if (_startingNewPuzzle) return;
    setState(() {
      _startingNewPuzzle = true;
      score = 0;
      _hintUnlocked = false;
    });
    await _loadPuzzle();
    if (!mounted) return;
    setState(() {
      _startingNewPuzzle = false;
    });
  }

  // Constrained puzzle generator contract:
  // - Inputs: size (N), words (10 strings A-Z)
  // - Behavior: place all words on NxN grid using directions:
  //   horizontal: right (0,1), left (0,-1)
  //   vertical:   down (1,0), up (-1,0)
  //   diagonal:   down-right (1,1), down-left (1,-1)
  //   Note: no upward diagonals; diagonals are only downward.
  //   Randomize direction mix slightly to avoid patterns; fill remaining with random A-Z.
  // - Output: Puzzle(grid, words)
  _Puzzle? _generateConstrainedPuzzle(int size, List<String> words) {
    final rnd = Random();
    // Sort longest first for higher placement success
    final sorted = List<String>.from(words.map((w) => w.toUpperCase()))
      ..sort((a, b) => b.length.compareTo(a.length));

    int attempts = 0;
    while (attempts < 200) {
      attempts++;
      final grid = List.generate(
        size,
        (_) => List<String>.filled(size, '', growable: false),
        growable: false,
      );
      bool failed = false;
      // Enforce a mix: target counts for directions (slightly randomized per attempt)
      int placedRight = 0;
      int placedLeft = 0;
      int placedDown = 0;
      int placedUp = 0;
      int placedDiagDR = 0;
      int placedDiagDL = 0;
      // Choose one of a few mixes summing to 10 with minimums: >=3 horizontal, >=3 vertical, >=2 diag total
      const mixes = <List<int>>[
        // [horizontalTotal, verticalTotal, diagTotal]
        [4, 4, 2],
        [4, 3, 3],
        [3, 4, 3],
        [5, 3, 2],
        [3, 5, 2],
        [3, 3, 4],
      ];
      final pick = mixes[rnd.nextInt(mixes.length)];
      final targetHoriz = pick[0];
      final targetVert = pick[1];
      final targetDiagTotal = pick[2];

      for (final word in sorted) {
        // Prioritize directions that are under target to meet the mix
        final choices = <_Dir>[];
        final placedHoriz = placedRight + placedLeft;
        final placedVert = placedDown + placedUp;
        if (placedHoriz < targetHoriz) {
          if (placedRight <= placedLeft) choices.add(const _Dir(0, 1));
          if (placedLeft <= placedRight) choices.add(const _Dir(0, -1));
        }
        if (placedVert < targetVert) {
          if (placedDown <= placedUp) choices.add(const _Dir(1, 0));
          if (placedUp <= placedDown) choices.add(const _Dir(-1, 0));
        }
        final placedDiagTotal = placedDiagDR + placedDiagDL;
        if (placedDiagTotal < targetDiagTotal) {
          // Prefer the diagonal that is currently underrepresented
          if (placedDiagDR <= placedDiagDL) choices.add(const _Dir(1, 1));
          if (placedDiagDL <= placedDiagDR) choices.add(const _Dir(1, -1));
        }
        if (choices.isEmpty) {
          choices.addAll(const [
            _Dir(0, 1), // right
            _Dir(0, -1), // left
            _Dir(1, 0), // down
            _Dir(-1, 0), // up
            _Dir(1, 1), // diag down-right
            _Dir(1, -1), // diag down-left
          ]);
        }
        choices.shuffle(rnd);

        bool placed = false;
        // Try up to some random positions per word
        int tries = 0;
        while (!placed && tries < 220) {
          tries++;
          final dir = choices[rnd.nextInt(choices.length)];
      // Only allow right/left, down/up, diag down-right, diag down-left (no upward diagonals)
          final allowed = (dir.dr == 0 && dir.dc == 1) ||
        (dir.dr == 0 && dir.dc == -1) ||
              (dir.dr == 1 && dir.dc == 0) ||
        (dir.dr == -1 && dir.dc == 0) ||
              (dir.dr == 1 && dir.dc == 1) ||
              (dir.dr == 1 && dir.dc == -1);
          if (!allowed) continue;
          // Compute valid start ranges based on direction
          final rowMin = dir.dr == -1
              ? (word.length - 1)
              : 0;
          final rowMax = dir.dr == 1
              ? size - word.length
              : size - 1;
          final colMin = dir.dc == -1
              ? (word.length - 1)
              : 0;
          final colMax = dir.dc == 1
              ? size - word.length
              : size - 1;
          if (rowMax < rowMin || colMax < colMin) continue;
          final row = rowMin + rnd.nextInt(rowMax - rowMin + 1);
          final col = colMin + rnd.nextInt(colMax - colMin + 1);
          if (_canPlace(grid, row, col, dir, word)) {
            _place(grid, row, col, dir, word);
            if (dir.dr == 0 && dir.dc == 1) placedRight++;
            else if (dir.dr == 0 && dir.dc == -1) placedLeft++;
            else if (dir.dr == 1 && dir.dc == 0) placedDown++;
            else if (dir.dr == -1 && dir.dc == 0) placedUp++;
            else if (dir.dr == 1 && dir.dc == 1) placedDiagDR++;
            else if (dir.dr == 1 && dir.dc == -1) placedDiagDL++;
            placed = true;
          }
        }
        if (!placed) {
          failed = true;
          break;
        }
      }

      if (!failed) {
  // Enforce a solid mix: at least 3 horizontal, 3 vertical, 2 diagonals total with both diag types present
  final placedDiagTotal2 = placedDiagDR + placedDiagDL;
  final placedHoriz2 = placedRight + placedLeft;
  final placedVert2 = placedDown + placedUp;
  if (!(placedHoriz2 >= 3 && placedVert2 >= 3 && placedDiagTotal2 >= 2 && placedDiagDR >= 1 && placedDiagDL >= 1)) {
          continue;
        }
        // Fill empties with random letters
        for (int r = 0; r < size; r++) {
          for (int c = 0; c < size; c++) {
            if (grid[r][c].isEmpty) {
              grid[r][c] = String.fromCharCode(rnd.nextInt(26) + 65);
            }
          }
        }
        return _Puzzle(grid: grid, words: sorted);
      }
    }
    // Unable to place all words within the attempt budget
    return null;
  }

  bool _canPlace(
    List<List<String>> grid,
    int row,
    int col,
    _Dir dir,
    String word,
  ) {
    final n = grid.length;
    final rEnd = row + dir.dr * (word.length - 1);
    final cEnd = col + dir.dc * (word.length - 1);
    if (rEnd < 0 || rEnd >= n || cEnd < 0 || cEnd >= n) return false;
    for (int i = 0; i < word.length; i++) {
      final r = row + dir.dr * i;
      final c = col + dir.dc * i;
      final cell = grid[r][c];
      if (cell.isNotEmpty && cell != word[i]) return false;
    }
    return true;
  }

  void _place(
    List<List<String>> grid,
    int row,
    int col,
    _Dir dir,
    String word,
  ) {
    for (int i = 0; i < word.length; i++) {
      final r = row + dir.dr * i;
      final c = col + dir.dc * i;
      grid[r][c] = word[i];
    }
  }

  // Confetti method inside State to use setState safely
  void _spawnConfetti() {
    final rand = Random();
    final colors = [
      const Color(0xFFD81B60),
      const Color(0xFFF4B400),
      const Color(0xFF00BCD4),
      const Color(0xFF8E24AA),
      const Color(0xFFE53935),
      const Color(0xFFFF7043),
      const Color(0xFF1E88E5),
      const Color(0xFF43A047),
      const Color(0xFFFFC107),
      const Color(0xFF7CB342),
      const Color(0xFF6D4C41),
      const Color(0xFF009688),
    ];
    _confetti = List.generate(28, (i) {
      final x =
          rand.nextDouble() * MediaQuery.of(context).size.width * 0.8 +
          MediaQuery.of(context).size.width * 0.1;
      final y =
          rand.nextDouble() * MediaQuery.of(context).size.width * 0.6 + 48;
      final size = rand.nextDouble() * 8 + 4;
      return _ConfettiDot(
        position: Offset(x, y),
        size: size,
        color: colors[i % colors.length],
        velocity: Offset(rand.nextDouble() * 4 - 2, rand.nextDouble() * 4 + 2),
        radius: size / 2,
        rotation: rand.nextDouble() * 6.28,
      );
    });
    setState(() => _showConfetti = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showConfetti = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Bolly Word Grid'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.amber[700]),
                const SizedBox(width: 4),
                Text(
                  '$score',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final settings = context.watch<FeedbackSettings>();
                    final canUseHints = settings.hintsEnabled && score >= 20 && _sel != null;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: canUseHints
                              ? const BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFFB388FF), // purple glow
                                      blurRadius: 16,
                                      spreadRadius: 1,
                                    ),
                                    BoxShadow(
                                      color: Color(0xFF8E24AA),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                )
                              : null,
                          child: IconButton(
                            tooltip: canUseHints
                                ? 'Hint (-15 points)'
                                : 'Hints unlock at 20 points',
                            onPressed: !canUseHints
                                ? null
                                : () {
                                    if (_sel == null) return;
                                    if (score < 15) return; // need enough points
                                    final sc = _sel!;
                                    final remaining = sc.remainingWords;
                                    if (remaining.isEmpty) return;
                                    final list = remaining.toList()..shuffle();
                                    final word = list.first;
                                    final start = sc.findWordStart(word);
                                    if (start != null) {
                                      setState(() => score -= 15);
                                      sc.showHintAt(start, durationMs: 1000);
                                    }
                                  },
                            icon: const Icon(Icons.help_outline),
                            iconSize: 22,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                            color: canUseHints ? Colors.white : Colors.white70,
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: canUseHints
                              ? const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Hint 15 points',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
  toolbarHeight: 68,
      ),
      body: PopScope(
        canPop: false,
        child: Column(
          children: [
            // Key box with chips
            Container(
              width: double.infinity,
              color: surface,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _themeTitle.isEmpty ? 'Loading…' : _themeTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A1B9A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: _clues.map((clue) {
                      final sc = _sel;
                      final isFound =
                          sc != null &&
                          sc.found.any(
                            (f) => f.word == clue.answer.toUpperCase(),
                          );
                      final color = sc?.wordColors[clue.answer.toUpperCase()];
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                          vertical: 3,
                          horizontal: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isFound && color != null ? color : surface,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: (color ?? outline),
                            width: 1,
                          ),
                          boxShadow: isFound
                              ? [
                                  BoxShadow(
                                    color: (color ?? Colors.black).withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: Stack(
                          children: [
                            // Simple left->right strike animation by clipping text width
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Text(
                                clue.label,
                                key: ValueKey(isFound),
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: isFound ? Colors.white : onSurface,
                                  decoration: isFound
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            // Compact film reel preview with individual cells for each letter
            if (_sel != null && _sel!.hasActive && _sel!.activeString.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 3), // Reduced by 20%
                child: Center(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 120),
                    scale: 1.0,
                    child: AnimatedOpacity(
                      key: ValueKey<String>('preview_${_sel!.activeString}'),
                      duration: const Duration(milliseconds: 120),
                      opacity: 1.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Reduced by 20%
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Left film reel edge
                            Container(
                              width: 10, // Reduced by 20%
                              height: 29, // Reduced by 20%
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E),
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                                border: Border.all(color: Colors.black38, width: 1),
                              ),
                              child: Center(
                                child: Container(
                                  width: 1.2, // Reduced by 20%
                                  height: 19, // Reduced by 20%
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                            // Letter cells
                            Row(
                              children: _sel!.activeString.split('').map((letter) {
                                return Container(
                                  width: 22, // Reduced by 20%
                                  height: 29, // Reduced by 20%
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: _sel!.activeColor,
                                    border: Border.all(
                                      color: _sel!.activeColor!.computeLuminance() > 0.5 
                                          ? Colors.black26 
                                          : Colors.white24,
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      letter,
                                      style: const TextStyle(
                                        fontSize: 14, // Reduced by 20%
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(0, 1),
                                            blurRadius: 2,
                                            color: Colors.black45,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            // Right film reel edge
                            Container(
                              width: 10, // Reduced by 20%
                              height: 29, // Reduced by 20%
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E),
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                                border: Border.all(color: Colors.black38, width: 1),
                              ),
                              child: Center(
                                child: Container(
                                  width: 1.2, // Reduced by 20%
                                  height: 19, // Reduced by 20%
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 35), // Reduced by 20%
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (_sel == null || grid == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return AnimatedBuilder(
                        animation: _sel!,
                        builder: (context, _) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              // Background gradient behind grid card
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: isDark
                                        ? const [
                                            Color(0xFF140B1B),
                                            Color(0xFF0E0E12),
                                          ]
                                        : const [
                                            Color(0xFFFFF7FB),
                                            Color(0xFFF5F5F7),
                                          ],
                                  ),
                                ),
                              ),
                              // Grid card with painter under letters (letters remain readable above)
                              Center(
                                child: Container(
                                  margin: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: surface,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.06,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.none,
                                  child: LayoutBuilder(
                                    builder: (context, inner) {
                                      return GestureDetector(
                                        onPanStart: (d) =>
                                            _onGridPanStart(d, inner),
                                        onPanUpdate: (d) =>
                                            _onGridPanUpdate(d, inner),
                                        onPanEnd: _onPanEnd,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          clipBehavior: Clip
                                              .none, // Allow painter to draw outside bounds (e.g., for shadows)
                                          children: [
                                            // Film reel painter (under letters)
                                            IgnorePointer(
                                              child: RepaintBoundary(
                                                child: CustomPaint(
                                                  painter: FilmReelPainter(
                                                    cellSize:
                                                        inner.maxWidth /
                                                        gridSize,
                                                    found: _sel!.found,
                                                    activePath:
                                                        _sel!.activePath,
                                                    activeColor:
                                                        _sel!.activeColor,
                                                    surfaceColor: surface,
                                                    debug: false,
                                                    repaint: Listenable.merge([
                                                      _sel!,
                                                      ..._sel!.found.map(
                                                        (fp) => fp.progress,
                                                      ),
                                                    ]),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Letters grid
                                            RepaintBoundary(
                                              child: GridView.builder(
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                itemCount: gridSize * gridSize,
                                                gridDelegate:
                                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                                      crossAxisCount: gridSize,
                                                    ),
                                                itemBuilder: (context, index) {
                                                  final row = index ~/ gridSize;
                                                  final col = index % gridSize;
                                                  final sc = _sel!;
                                                  final cellOffset = Offset(
                                                    row.toDouble(),
                                                    col.toDouble(),
                                                  );
                                                  final inSelected = sc
                                                      .activePath
                                                      .contains(cellOffset);
                                                  final inFound =
                                                      _isInFoundPaths(
                                                        cellOffset,
                                                        sc,
                                                      );
                                                  // Responsive font size based on inner width
                                                  final tile =
                                                      inner.maxWidth / gridSize;
                                                  final fontSize = tile * 0.34;
                                                  return AnimatedScale(
                                                    duration: const Duration(
                                                      milliseconds: 100,
                                                    ),
                                                    scale: inSelected
                                                        ? 1.08
                                                        : 1.0,
                                                    child: Container(
                                                      margin:
                                                          const EdgeInsets.all(
                                                            2.5,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.transparent,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              inSelected ||
                                                                      inFound
                                                                  ? 10
                                                                  : 8,
                                                            ),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          grid![row][col],
                                                          style: TextStyle(
                                                            fontSize: fontSize,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color:
                                                                (inSelected ||
                                                                    inFound)
                                                                ? Colors.white
                                                                : onSurface,
                                                            shadows: const [
                                                              Shadow(
                                                                color: Colors
                                                                    .black38,
                                                                blurRadius: 2,
                                                                offset: Offset(
                                                                  0,
                                                                  1,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              // ...existing code...
                              // Confetti overlay
                              _showConfetti
                                  ? _ConfettiLayer(dots: _confetti)
                                  : const SizedBox.shrink(),
                              // Win-state overlay with Play again button
                              if (_sel?.isComplete == true)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black.withOpacity(0.35),
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'All names found! 🎉',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        FilledButton.icon(
                                          onPressed: _startingNewPuzzle ? null : _playAgain,
                                          icon: const Icon(Icons.refresh),
                                          label: Text(
                                            _startingNewPuzzle ? 'Loading…' : 'Play again',
                                          ),
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                            backgroundColor: Theme.of(context).colorScheme.primary,
                                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A simple class to hold confetti particle state
class _ConfettiDot {
  final Offset position;
  final Offset velocity;
  final Color color;
  final double radius;
  final double rotation;
  final double size;

  _ConfettiDot({
    required this.position,
    required this.velocity,
    required this.color,
    required this.radius,
    required this.rotation,
    required this.size,
  });
}

class _ConfettiLayer extends StatelessWidget {
  const _ConfettiLayer({required this.dots});
  final List<_ConfettiDot> dots;
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final d in dots)
            Positioned(
              left: d.position.dx,
              top: d.position.dy,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 700),
                opacity: 0.0,
                curve: Curves.easeOut,
                child: Container(
                  width: d.size,
                  height: d.size,
                  decoration: BoxDecoration(
                    color: d.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Puzzle {
  final List<List<String>> grid;
  final List<String> words;
  _Puzzle({required this.grid, required this.words});
}

class _Dir {
  final int dr;
  final int dc;
  const _Dir(this.dr, this.dc);
}
