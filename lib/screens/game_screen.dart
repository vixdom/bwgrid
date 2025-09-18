import 'dart:math';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ads/ads_config.dart';
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
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPuzzle());
    // Load banner ad on both Android and iOS
    final adUnitId = Platform.isAndroid ? AdsConfig.androidBanner : AdsConfig.iosBanner;
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() => _isBannerAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    _bannerAd!.load();
  }

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
      final gameController = context.read<GameController>();
      unawaited(gameController.onNewCellSelected());
    }
  }

  void _onGridPanUpdate(DragUpdateDetails details, BoxConstraints inner) {
    if (_sel == null || !_sel!.hasActive) return;
    final cell = inner.maxWidth / gridSize;
    final col = (details.localPosition.dx / cell).floor();
    final row = (details.localPosition.dy / cell).floor();
    
    if (row >= 0 && row < gridSize && col >= 0 && col < gridSize) {
      final currentCell = Offset(row.toDouble(), col.toDouble());
      if (_sel!.activePath.isEmpty || _sel!.activePath.last != currentCell) {
        final changed = _sel!.extendTo(currentCell);
        if (changed) {
          setState(() {});
          final gameController = context.read<GameController>();
          unawaited(gameController.onNewCellSelected());
        }
      }
    }
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    final wasActive = _sel?.hasActive == true;
    final prevLen = _sel?.activePath.length ?? 0;
    final found = _sel?.commitOrReset();
    final gc = context.read<GameController>();
    setState(() {});
    
    if (found != null) {
      setState(() => score += 10);
      await gc.onWordFound();
      if (!_hintUnlocked && score >= 20) {
        _hintUnlocked = true;
        unawaited(gc.feedback.playClue());
      }
      // ignore: use_build_context_synchronously
      SemanticsService.announce(
        'Found ${found.word}. ${_sel?.found.length ?? 0} of 10 words.',
        TextDirection.ltr,
      );
      if (_sel?.isComplete == true) {
        await gc.onPuzzleComplete();
        _spawnConfetti();
      }
    } else if (wasActive && prevLen >= 2) {
      await gc.onInvalid();
    }
  }

  bool _isInFoundPaths(Offset cell, SelectionController sc) {
    for (final fp in sc.found) {
      for (final o in fp.points) {
        if (o == cell) return true;
      }
    }
    return false;
  }

  // Score
  int score = 0;
  bool _hintUnlocked = false;

  Future<void> _loadPuzzle() async {
    final dict = await ThemeDictionary.loadFromAsset(
      'assets/key and themes.txt',
    );
    final picked = dict.pickRandom(10, maxLen: gridSize);
    final theme =
        picked ??
        (dict.themes.isNotEmpty
            ? dict.themes.first
            : ThemeEntry(name: 'Bolly Words', names: const []));
    final clues = theme.pickClues(10, maxLen: gridSize);
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

    debugPrint('Selected words: ${chosen.map((c) => '${c.answer}(${c.answer.length})').join(', ')}');

    setState(() {
      _themeTitle = theme.name.toUpperCase();
      _clues = List<Clue>.from(chosen);
      grid = null;
      _sel = null;
    });

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
      debugPrint('Constrained algorithm failed, trying simpler approach...');
      puzzle = _generateSimplePuzzle(gridSize, chosen.map((c) => c.answer).toList());
      if (puzzle != null) {
        debugPrint('Simple algorithm succeeded');
      } else {
        debugPrint('Simple algorithm also failed');
      }
    }

    if (puzzle == null) {
      debugPrint('Failed to generate a valid puzzle after $maxAttempts attempts');
      return;
    }

    // Success: apply puzzle grid and initialize selection controller
    final newGrid = puzzle.grid;
    final targetWords = chosen.map((c) => c.answer.toUpperCase()).toSet();
    setState(() {
      grid = newGrid;
      _sel = SelectionController(
        grid: newGrid,
        gridSize: gridSize,
        targetWords: targetWords,
      );
    });
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

  _Puzzle? _generateConstrainedPuzzle(int size, List<String> words) {
    final rnd = Random();
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
      int placedRight = 0;
      int placedLeft = 0;
      int placedDown = 0;
      int placedUp = 0;
      int placedDiagDR = 0;
      int placedDiagDL = 0;
      const mixes = <List<int>>[
        [4, 4, 2],
        [4, 3, 3],
        [3, 4, 3],
        [5, 3, 2],
        [3, 5, 2],
        [3, 3, 4],
        [4, 5, 1],
        [5, 4, 1],
        [6, 3, 1],
      ];
      final pick = mixes[rnd.nextInt(mixes.length)];
      final targetHoriz = pick[0];
      final targetVert = pick[1];
      final targetDiagTotal = pick[2];

      for (final word in sorted) {
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
          if (placedDiagDR <= placedDiagDL) choices.add(const _Dir(1, 1));
          if (placedDiagDL <= placedDiagDR) choices.add(const _Dir(1, -1));
        }
        if (choices.isEmpty) {
          choices.addAll(const [
            _Dir(0, 1),
            _Dir(0, -1),
            _Dir(1, 0),
            _Dir(-1, 0),
            _Dir(1, 1),
            _Dir(1, -1),
          ]);
        }
        choices.shuffle(rnd);

        bool placed = false;
        int tries = 0;
        while (!placed && tries < 220) {
          tries++;
          final dir = choices[rnd.nextInt(choices.length)];
          final allowed = (dir.dr == 0 && dir.dc == 1) ||
              (dir.dr == 0 && dir.dc == -1) ||
              (dir.dr == 1 && dir.dc == 0) ||
              (dir.dr == -1 && dir.dc == 0) ||
              (dir.dr == 1 && dir.dc == 1) ||
              (dir.dr == 1 && dir.dc == -1);
          if (!allowed) continue;
          final rowMin = dir.dr == -1 ? (word.length - 1) : 0;
          final rowMax = dir.dr == 1 ? size - word.length : size - 1;
          final colMin = dir.dc == -1 ? (word.length - 1) : 0;
          final colMax = dir.dc == 1 ? size - word.length : size - 1;
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
        final placedDiagTotal2 = placedDiagDR + placedDiagDL;
        final placedHoriz2 = placedRight + placedLeft;
        final placedVert2 = placedDown + placedUp;
        if (!(placedHoriz2 >= 2 && placedVert2 >= 2 && placedDiagTotal2 >= 1)) {
          continue;
        }
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
    return null;
  }

  _Puzzle? _generateSimplePuzzle(int size, List<String> words) {
    final rnd = Random();
    final sorted = List<String>.from(words.map((w) => w.toUpperCase()))
      ..sort((a, b) => b.length.compareTo(a.length));

    int attempts = 0;
    while (attempts < 500) {
      attempts++;
      final grid = List.generate(
        size,
        (_) => List<String>.filled(size, '', growable: false),
        growable: false,
      );
      bool failed = false;

      for (final word in sorted) {
        final choices = const [
          _Dir(0, 1),
          _Dir(0, -1),
          _Dir(1, 0),
          _Dir(-1, 0),
          _Dir(1, 1),
          _Dir(1, -1),
        ];
        choices.shuffle(rnd);

        bool placed = false;
        int tries = 0;
        while (!placed && tries < 150) {
          tries++;
          final dir = choices[rnd.nextInt(choices.length)];
          final rowMin = dir.dr == -1 ? (word.length - 1) : 0;
          final rowMax = dir.dr == 1 ? size - word.length : size - 1;
          final colMin = dir.dc == -1 ? (word.length - 1) : 0;
          final colMax = dir.dc == 1 ? size - word.length : size - 1;
          if (rowMax < rowMin || colMax < colMin) continue;
          final row = rowMin + rnd.nextInt(rowMax - rowMin + 1);
          final col = colMin + rnd.nextInt(colMax - colMin + 1);
          if (_canPlace(grid, row, col, dir, word)) {
            _place(grid, row, col, dir, word);
            placed = true;
          }
        }
        if (!placed) {
          failed = true;
          break;
        }
      }

      if (!failed) {
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
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900; // tablet breakpoint

  return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AnimatedRotation(
          duration: const Duration(milliseconds: 300),
          turns: 0.0, // Can animate on press if needed
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: _GoldenTicket(score: score),
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) {
              final settings = context.watch<FeedbackSettings>();
              final canUseHints = settings.hintsEnabled && score >= 20 && _sel != null;
              return FloatingActionButton.small(
                onPressed: !canUseHints
                    ? null
                    : () {
                        if (_sel == null) return;
                        if (score < 15) return;
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
                tooltip: canUseHints
                    ? 'Hint (-15 tickets)'
                    : 'Hints unlock at 20 tickets',
                child: const Icon(Icons.question_mark),
                backgroundColor: canUseHints ? Colors.amber : Colors.grey,
              );
            },
          ),
        ],
        toolbarHeight: isWide ? 76 : 68,
      ),
      body: PopScope(
        canPop: false,
        child: Column(
          children: [
            // Theme name bar
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.primaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                _themeTitle.isEmpty ? 'Bolly Word Grid' : _themeTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Key box with chips
            Container(
              width: double.infinity,
              color: surface,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: _clues.map((clue) {
                      final sc = _sel;
                      final isFound = sc != null && sc.found.any((f) => f.word == clue.answer.toUpperCase());
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
                                    color: (color ?? Colors.black).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          clue.label,
                          style: TextStyle(
                            fontSize: (isWide ? 14 : 11) * 1.15, // +15%
                            fontWeight: FontWeight.w700,
                            color: isFound ? Colors.white : onSurface,
                            decoration: isFound ? TextDecoration.lineThrough : TextDecoration.none,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            // Selection preview
            if (_sel != null && _sel!.hasActive && _sel!.activeString.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 3),
                child: Center(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 120),
                    scale: 1.0,
                    child: AnimatedOpacity(
                      key: ValueKey<String>('preview_${_sel!.activeString}'),
                      duration: const Duration(milliseconds: 120),
                      opacity: 1.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                            Container(
                              width: 10,
                              height: 29,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E),
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                                border: Border.all(color: Colors.black38, width: 1),
                              ),
                              child: Center(
                                child: Container(
                                  width: 1.2,
                                  height: 19,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                            Row(
                              children: _sel!.activeString.split('').map((letter) {
                                return Container(
                                  width: 22,
                                  height: 29,
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
                                        fontSize: 14,
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
                            Container(
                              width: 10,
                              height: 29,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1C1C1E),
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                                border: Border.all(color: Colors.black38, width: 1),
                              ),
                              child: Center(
                                child: Container(
                                  width: 1.2,
                                  height: 19,
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
              const SizedBox(height: 35),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (context, inner) {
                      if (_sel == null || grid == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return AnimatedBuilder(
                        animation: _sel!,
                        builder: (context, _) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Center(
                                child: Container(
                                  margin: const EdgeInsets.all(12),
                                      decoration: const BoxDecoration(),
                                  clipBehavior: Clip.none,
                                  child: LayoutBuilder(
                                    builder: (context, inner2) {
                                      return GestureDetector(
                                        onPanStart: (d) => _onGridPanStart(d, inner2),
                                        onPanUpdate: (d) => _onGridPanUpdate(d, inner2),
                                        onPanEnd: _onPanEnd,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          clipBehavior: Clip.none,
                                          children: [
                                            IgnorePointer(
                                              child: RepaintBoundary(
                                                child: CustomPaint(
                                                  painter: FilmReelPainter(
                                                    cellSize: inner2.maxWidth / gridSize,
                                                    found: _sel!.found,
                                                    activePath: _sel!.activePath,
                                                    activeColor: _sel!.activeColor,
                                                    surfaceColor: surface,
                                                    debug: false,
                                                    repaint: Listenable.merge([
                                                      _sel!,
                                                      ..._sel!.found.map((fp) => fp.progress),
                                                    ]),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            RepaintBoundary(
                                              child: GridView.builder(
                                                physics: const NeverScrollableScrollPhysics(),
                                                itemCount: gridSize * gridSize,
                                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: gridSize,
                                                ),
                                                itemBuilder: (context, index) {
                                                  final row = index ~/ gridSize;
                                                  final col = index % gridSize;
                                                  final sc = _sel!;
                                                  final cellOffset = Offset(row.toDouble(), col.toDouble());
                                                  final inSelected = sc.activePath.contains(cellOffset);
                                                  final inFound = _isInFoundPaths(cellOffset, sc);
                                                  final tile = inner2.maxWidth / gridSize;
                                                  final fontSize = ((tile * 0.55).clamp(14.0, isWide ? 48.0 : 36.0)) * 1.0;
                                                  return AnimatedScale(
                                                    duration: const Duration(milliseconds: 100),
                                                    scale: inSelected ? 1.08 : 1.0,
                                                    child: Container(
                                                      margin: const EdgeInsets.all(2.5),
                                                      decoration: BoxDecoration(
                                                        color: Colors.transparent,
                                                        borderRadius: BorderRadius.circular(inSelected || inFound ? 10 : 8),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          grid![row][col],
                                                          style: TextStyle(
                                                            fontSize: fontSize,
                                                            fontWeight: FontWeight.normal,
                                                            color: (inSelected || inFound) ? Colors.white : onSurface,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            // Grid overlay with horizontal and vertical lines
                                            RepaintBoundary(
                                              child: CustomPaint(
                                                painter: _GridPainter(
                                                  gridSize: gridSize,
                                                  cellSize: inner2.maxWidth / gridSize,
                                                  lineColor: Colors.grey.withOpacity(0.4),
                                                  lineWidth: 1.0,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              _showConfetti ? _ConfettiLayer(dots: _confetti) : const SizedBox.shrink(),
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
                                          label: Text(_startingNewPuzzle ? 'Loading…' : 'Play again'),
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
            if (_isBannerAdLoaded && _bannerAd != null)
              SafeArea(
                top: false,
                child: Container(
                  alignment: Alignment.center,
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}

class _GridPainter extends CustomPainter {
  final int gridSize;
  final double cellSize;
  final Color lineColor;
  final double lineWidth;

  _GridPainter({
    required this.gridSize,
    required this.cellSize,
    required this.lineColor,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // Draw vertical lines
    for (int i = 0; i <= gridSize; i++) {
      final x = i * cellSize;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (int i = 0; i <= gridSize; i++) {
      final y = i * cellSize;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.gridSize != gridSize ||
           oldDelegate.cellSize != cellSize ||
           oldDelegate.lineColor != lineColor ||
           oldDelegate.lineWidth != lineWidth;
  }
}

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

class _GoldenTicket extends StatelessWidget {
  const _GoldenTicket({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFD700)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFFFD700), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 2,
                  color: Colors.white.withOpacity(0.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'tickets',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
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
