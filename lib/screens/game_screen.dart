import 'dart:math';
import 'dart:async';
import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ads/ads_config.dart';
import '../services/game_controller.dart';
import '../services/interstitial_ad_manager.dart';
import '../controllers/selection_controller.dart';
import '../widgets/film_reel_painter.dart';
import '../widgets/glass_surface.dart';
import '../widgets/progress_path_screen.dart';
import '../services/theme_dictionary.dart';
import '../models/feedback_settings.dart';
import '../services/animation_manager.dart';
import '../models/stage_scene.dart';
import '../services/game_persistence.dart';
import '../services/rating_service.dart';
import '../constants/app_themes.dart';
import '../services/wallet_service.dart';

enum _SecretCorner { topRight, bottomRight, bottomLeft, topLeft }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.forceShowProgressPath = false});

  final bool forceShowProgressPath;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
  with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Optimized state management with ValueNotifiers to reduce rebuilds
  late final ValueNotifier<bool> _hintUnlockedNotifier;
  late final ValueNotifier<bool> _showConfettiNotifier;
  late final ValueNotifier<SelectionController?> _selectionNotifier;
  
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
  static const List<_SecretCorner> _autoCompleteSequence = <_SecretCorner>[
    _SecretCorner.topRight,
    _SecretCorner.bottomRight,
    _SecretCorner.bottomLeft,
    _SecretCorner.topLeft,
  ];
  static const List<int> _autoCompleteTapTargets = <int>[1, 2, 3, 4];
  static const Duration _autoCompleteResetDelay = Duration(seconds: 6);
  List<List<String>>? grid;
  SelectionController? _sel;
  List<ConfettiParticle> _confetti = const [];
  late AnimationController _confettiController;
  late Animation<double> _confettiAnimation;
  String _themeTitle = '';
  List<Clue> _clues = const [];
  bool _startingNewPuzzle = false;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  static const List<SceneDefinition> _fallbackScenes = [
    SceneDefinition(index: 1, title: 'Spotlight Search', mode: SceneMode.classic),
    SceneDefinition(index: 2, title: 'Hidden Names', mode: SceneMode.hiddenClues),
    SceneDefinition(index: 3, title: 'Lightning Round', mode: SceneMode.timed, timeLimit: Duration(seconds: 90)),
  ];
  late final List<StageDefinition> _allStages = StagePlaybook.getAllStages();
  int _currentStageIndex = 0;
  StageDefinition get _stageDefinition => _allStages[_currentStageIndex];
  List<SceneDefinition> get _sceneSchedule => _stageDefinition.scenes.length >= 2
      ? _stageDefinition.scenes
      : _fallbackScenes;
  int _currentSceneIndex = 0;
  ThemeDictionary? _themeDictionary;
  ThemeEntry? _stageTheme;
  final Set<String> _usedAnswers = <String>{};
  final Set<String> _revealedClues = <String>{};
  Timer? _sceneTimer;
  int? _remainingSeconds;
  int? _sceneDurationSeconds;
  bool _timeExpired = false;
  bool _sceneActive = false;
  int _metronomeBeat = 0;
  bool _scrollLocked = false;
  late final ScrollController _gameScrollController;
  bool _showClapboard = false;
  String _clapboardLabel = '';
  String _clapboardSubtitle = '';
  bool _restoringFromSave = false;
  Timer? _saveDebounce;
  Timer? _clapboardTimer;
  Timer? _autoCompleteResetTimer;
  int _autoCompleteStage = 0;
  int _autoCompleteTapCount = 0;
  bool _autoCompleting = false;
  final GamePersistence _gamePersistence = const GamePersistence();
  final RatingService _ratingService = RatingService();
  bool _showProgressPath = false;
  bool _hasShownHintReminder = false;
  bool _dangerHapticTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _showProgressPath = widget.forceShowProgressPath;
    _gameScrollController = ScrollController();
    // Initialize ValueNotifiers
    _hintUnlockedNotifier = ValueNotifier<bool>(false);
    _showConfettiNotifier = ValueNotifier<bool>(false);
    _selectionNotifier = ValueNotifier<SelectionController?>(null);
    
    // Initialize optimized animation controller
    _confettiController = AnimationManager().getController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
      id: 'confetti',
    );
    
    _confettiAnimation = AnimationManager().createAnimation(
      controller: _confettiController,
      begin: 0.0,
      end: 1.0,
      curveName: 'easeOut',
      id: 'confetti_progress',
    );
    
  // Restore or initialize game state with built-in stage order
  unawaited(_restoreOrInitializeStage());
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

  // Warm up an interstitial at startup so it's likely ready at the first break
  final interstitialUnit = Platform.isAndroid
    ? AdsConfig.androidInterstitial
    : AdsConfig.iosInterstitial;
  InterstitialAdManager.instance.load(adUnitId: interstitialUnit);
  }

  // (CSV ordering is now baked into StagePlaybook; no dynamic order at runtime)

  // Grid-local gesture mapping using inner constraints
  void _onGridPanStart(DragStartDetails details, BoxConstraints inner) {
    if (_sel == null || !_sceneActive || _timeExpired) {
      return;
    }
    final cell = inner.maxWidth / gridSize;
    final col = (details.localPosition.dx / cell).floor();
    final row = (details.localPosition.dy / cell).floor();
    if (row >= 0 && row < gridSize && col >= 0 && col < gridSize) {
      _handleAutoCompleteTap(row, col);
      if (_autoCompleting) {
        _setScrollLocked(false);
        return;
      }
      setState(() {
        _sel!.beginAt(Offset(row.toDouble(), col.toDouble()));
      });
      final gameController = context.read<GameController>();
      unawaited(gameController.onNewCellSelected());
    }
  }

  void _onGridPanUpdate(DragUpdateDetails details, BoxConstraints inner) {
    if (_sel == null || !_sel!.hasActive || !_sceneActive || _timeExpired) return;
    final cell = inner.maxWidth / gridSize;
    final col = (details.localPosition.dx / cell).floor();
    final row = (details.localPosition.dy / cell).floor();
    
    if (row >= 0 && row < gridSize && col >= 0 && col < gridSize) {
      final currentCell = Offset(row.toDouble(), col.toDouble());
      if (_sel!.activePath.isEmpty || _sel!.activePath.last != currentCell) {
        final changed = _sel!.extendTo(currentCell);
        if (changed) {
          // Only update the selection notifier, avoid full widget rebuild
          _selectionNotifier.value = _sel;
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
    // Update selection notifier instead of setState
    _selectionNotifier.value = _sel;
    
    if (found != null) {
      // Update score using ValueNotifier
      _changeScore(10);
      await gc.onWordFound();
      if (!_hintUnlocked && WalletService.instance.tickets >= 20) {
        _hintUnlockedNotifier.value = true;
        unawaited(gc.feedback.playClue());
      }
      // ignore: use_build_context_synchronously
      // ignore: deprecated_member_use
      SemanticsService.announce(
        'Found ${found.word}. ${_sel?.found.length ?? 0} of 10 words.',
        TextDirection.ltr,
      );
      if (_sel?.isComplete == true) {
        _resetAutoCompleteSequence();
        await _cancelSceneTimer(
          resumeBackground: true,
          controllerOverride: gc,
        );
        setState(() {
          _sceneActive = false;
        });
        // Always play fireworks/applause when completing scene 3
        final playSound = _isFinalScene;
        await gc.onPuzzleComplete(playSound: playSound);
        _spawnConfetti();
      }
      _schedulePersistGameState();
    } else if (wasActive && prevLen >= 2) {
      await gc.onInvalid();
    }
    _setScrollLocked(false);
  }

  void _handleGridPanDown() {
    if (_sel == null || !_sceneActive || _timeExpired) {
      _setScrollLocked(false);
      return;
    }
    _setScrollLocked(true);
  }

  void _setScrollLocked(bool locked) {
    if (_scrollLocked == locked) return;
    setState(() {
      _scrollLocked = locked;
    });
  }

  bool _isInFoundPaths(Offset cell, SelectionController sc) {
    for (final fp in sc.found) {
      for (final o in fp.points) {
        if (o == cell) return true;
      }
    }
    return false;
  }

  // Optimized getters using ValueNotifiers
  bool get _hintUnlocked => _hintUnlockedNotifier.value;
  SceneDefinition get _currentScene => _sceneSchedule[_currentSceneIndex];
  bool get _isHiddenScene => _currentScene.mode == SceneMode.hiddenClues;
  bool get _isTimedScene => _currentScene.mode == SceneMode.timed;

  bool get _hasMoreScenes => (_currentSceneIndex + 1) < _sceneSchedule.length;

  bool get _isFinalScene {
  final finalScene = !_hasMoreScenes;
  debugPrint('🎬 Scene check: _currentSceneIndex=$_currentSceneIndex, totalScenes=${_sceneSchedule.length}, finalScene=$finalScene');
    return finalScene;
  }

  String get _sceneHeaderLabel {
    final screenIndex = _stageDefinition.index;
    final rawTheme = (_stageTheme?.name ?? _stageDefinition.themeName).trim();
    final themeName = rawTheme.isEmpty ? 'Bolly Word Grid' : rawTheme;
    final sceneNumber = _currentScene.index;
    final result = 'Screen $screenIndex: $themeName Scene $sceneNumber';
    debugPrint('🎬 _sceneHeaderLabel: _currentSceneIndex=$_currentSceneIndex, sceneNumber=$sceneNumber, result=$result');
    return result;
  }

  void _changeScore(int delta, {bool allowHintReminder = true}) {
    final wallet = WalletService.instance;
    final prev = wallet.tickets;
    if (delta > 0) {
      wallet.addTickets(delta);
    } else {
      wallet.spendTickets(delta.abs());
    }
    final next = wallet.tickets;

    final crossedThreshold = delta > 0 && allowHintReminder && !_hasShownHintReminder && prev < 20 && next >= 20;

    if (crossedThreshold) {
      _hasShownHintReminder = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hints unlock at 20 tickets. Tap the ? icon any time you need help.'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (!_hasShownHintReminder && next >= 20) {
      // Respect future increments that begin above the threshold without spamming toasts.
      _hasShownHintReminder = true;
    }
  }

  Future<void> _restoreOrInitializeStage() async {
    final saved = await _gamePersistence.load();
    if (!mounted) return;
    if (saved != null) {
      final restored = await _restoreSavedGame(saved);
      if (restored) {
        return;
      }
      await _gamePersistence.clear();
    }
    await _initializeStage();
  }

  Future<bool> _restoreSavedGame(SavedGameState state) async {
    // Validate stage index
    if (state.stageIndex < 1 || state.stageIndex > _allStages.length) {
      return false;
    }
    // Set stage index (1-indexed in save, 0-indexed in array)
    _currentStageIndex = state.stageIndex - 1;
    
    if (state.sceneIndex < 0 || state.sceneIndex >= _sceneSchedule.length) {
      return false;
    }
    if (state.gridRows.isEmpty) {
      return false;
    }

    final expectedTheme = _stageDefinition.themeName.trim().toLowerCase();
    final savedTheme = state.themeName.trim().toLowerCase();
    if (savedTheme != expectedTheme) {
      debugPrint('🎬 _restoreSavedGame: Theme mismatch (saved=$savedTheme, expected=$expectedTheme) → rejecting save');
      return false;
    }

    final dict = _themeDictionary ??
        await ThemeDictionary.loadFromAsset('assets/key and themes.txt');
    final theme = dict.findByName(state.themeName);
    if (theme.name.trim().toLowerCase() != expectedTheme) {
      debugPrint('🎬 _restoreSavedGame: Theme lookup mismatch (found=${theme.name}, expected=$expectedTheme) → rejecting save');
      return false;
    }

    final rows = <List<String>>[];
    for (final row in state.gridRows) {
      final chars = row.trim().toUpperCase().split('');
      if (chars.length != gridSize) {
        return false;
      }
      rows.add(List<String>.from(chars));
    }

    final targetWords = state.clues.map((c) => c.answer).toSet();
    final controller = SelectionController(
      grid: rows.map((r) => List<String>.from(r)).toList(),
      gridSize: gridSize,
      targetWords: targetWords,
    );
    controller.restoreFoundWords(state.foundWords);

  await _cancelSceneTimer(resumeBackground: false);
    _restoringFromSave = true;

    setState(() {
      _themeDictionary = dict;
      _stageTheme = theme;
      _currentSceneIndex = state.sceneIndex;
      _themeTitle = state.themeName.toUpperCase();
      _clues = List<Clue>.from(state.clues);
      _usedAnswers
        ..clear()
        ..addAll(state.usedAnswers);
      _revealedClues
        ..clear()
        ..addAll(state.revealedClues);
      grid = rows;
      _sel = controller;
      _selectionNotifier.value = controller;
      _hintUnlockedNotifier.value = state.hintUnlocked;
      _sceneDurationSeconds = state.sceneDurationSeconds ??
          _sceneSchedule[state.sceneIndex].timeLimit?.inSeconds;
      _remainingSeconds = state.remainingSeconds ?? _sceneDurationSeconds;
      _timeExpired = state.timeExpired;
      _sceneActive = state.sceneActive && !_timeExpired && !(controller.isComplete);
      _metronomeBeat = 0;
      _showProgressPath = true;
      _hasShownHintReminder = WalletService.instance.tickets >= 20;
      _dangerHapticTriggered = false;
    });

    _restoringFromSave = false;

    final shouldResumeTimer =
        _sceneActive && _isTimedScene && (_remainingSeconds ?? 0) > 0;
    if (shouldResumeTimer) {
      final remaining = _remainingSeconds!.clamp(0, 5999).toInt();
      await _startSceneTimer(Duration(seconds: remaining));
    }

    _showSceneIntro();
    _schedulePersistGameState();
    return true;
  }

  void _schedulePersistGameState({bool immediate = false}) {
    if (_restoringFromSave) return;
    if (immediate) {
      _saveDebounce?.cancel();
      _saveDebounce = null;
      unawaited(_persistGameState());
      return;
    }
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 900), () {
      _saveDebounce?.cancel();
      _saveDebounce = null;
      unawaited(_persistGameState());
    });
  }

  void _resetAutoCompleteSequence() {
    _autoCompleteResetTimer?.cancel();
    _autoCompleteResetTimer = null;
    _autoCompleteStage = 0;
    _autoCompleteTapCount = 0;
  }

  void _scheduleAutoCompleteTimeout() {
    _autoCompleteResetTimer?.cancel();
    _autoCompleteResetTimer =
        Timer(_autoCompleteResetDelay, _resetAutoCompleteSequence);
  }

  bool _cellMatchesCorner(int row, int col, _SecretCorner corner) {
    final maxIndex = gridSize - 1;
    switch (corner) {
      case _SecretCorner.topRight:
        return row == 0 && col == maxIndex;
      case _SecretCorner.bottomRight:
        return row == maxIndex && col == maxIndex;
      case _SecretCorner.bottomLeft:
        return row == maxIndex && col == 0;
      case _SecretCorner.topLeft:
        return row == 0 && col == 0;
    }
  }

  void _handleAutoCompleteTap(int row, int col) {
    if (_sel == null || !_sceneActive || _timeExpired || _autoCompleting) {
      _resetAutoCompleteSequence();
      return;
    }
    if (_autoCompleteStage >= _autoCompleteSequence.length) {
      _resetAutoCompleteSequence();
    }

    final corner = _autoCompleteSequence[_autoCompleteStage];
    if (_cellMatchesCorner(row, col, corner)) {
      _autoCompleteTapCount++;
      _scheduleAutoCompleteTimeout();
      final required = _autoCompleteTapTargets[_autoCompleteStage];
      if (_autoCompleteTapCount >= required) {
        _autoCompleteStage++;
        _autoCompleteTapCount = 0;
        if (_autoCompleteStage >= _autoCompleteSequence.length) {
          _resetAutoCompleteSequence();
          unawaited(_autoCompletePuzzle());
        }
      }
    } else {
      final matchesStart =
          _cellMatchesCorner(row, col, _autoCompleteSequence.first);
      _resetAutoCompleteSequence();
      if (matchesStart) {
        _autoCompleteTapCount = 1;
        _scheduleAutoCompleteTimeout();
      }
    }
  }

  Future<void> _autoCompletePuzzle() async {
    if (!mounted) return;
    final controller = _sel;
    if (controller == null || controller.isComplete) {
      return;
    }
    final remaining = controller.remainingWords.toList(growable: false);
    if (remaining.isEmpty) {
      return;
    }

    _autoCompleting = true;
    try {
      final gc = context.read<GameController>();
      bool allowHintReminder = !_hasShownHintReminder;
      int wordsAdded = 0;

      for (final word in remaining) {
        final path = controller.pathForWord(word);
        if (path == null) {
          continue;
        }
        final added = controller.forceAddWord(word, path);
        if (added != null) {
          wordsAdded++;
          _changeScore(10, allowHintReminder: allowHintReminder);
          allowHintReminder = false;
        }
      }

      if (wordsAdded == 0) {
        return;
      }

      _selectionNotifier.value = controller;

      if (!_hintUnlocked && WalletService.instance.tickets >= 20) {
        _hintUnlockedNotifier.value = true;
      }

      if (!controller.isComplete) {
        return;
      }

      await _cancelSceneTimer(
        resumeBackground: true,
        controllerOverride: gc,
      );
      if (!mounted) return;
      setState(() {
        _sceneActive = false;
      });
      await gc.onPuzzleComplete(playSound: false);
      _spawnConfetti();
      _schedulePersistGameState(immediate: true);
    } catch (e) {
      debugPrint('Error during autocomplete cheat: $e');
    } finally {
      _autoCompleting = false;
    }
  }

  Future<void> _persistGameState() async {
    if (!mounted) return;
    final controller = _sel;
    final currentGrid = grid;
    if (controller == null || currentGrid == null) {
      await _gamePersistence.clear();
      return;
    }
    if (controller.isComplete) {
      await _gamePersistence.clear();
      return;
    }

    final rows = currentGrid.map((row) => row.join()).toList(growable: false);
    final saved = SavedGameState(
      stageIndex: _stageDefinition.index,
      sceneIndex: _currentSceneIndex,
      themeName: _stageTheme?.name ?? _stageDefinition.themeName,
      gridRows: rows,
      clues: List<Clue>.from(_clues),
      usedAnswers: List<String>.from(_usedAnswers),
      revealedClues: List<String>.from(_revealedClues),
      foundWords: controller.found.map((fp) => fp.word).toList(growable: false),
      score: WalletService.instance.tickets,
      hintUnlocked: _hintUnlocked,
      sceneActive: _sceneActive,
      remainingSeconds: _remainingSeconds,
      sceneDurationSeconds: _sceneDurationSeconds,
      timeExpired: _timeExpired,
    );

    await _gamePersistence.save(saved);
  }

  Future<void> _initializeStage() async {
    debugPrint('🎬 _initializeStage: stage="${_stageDefinition.name}", totalScenes=${_sceneSchedule.length}');
    for (var i = 0; i < _sceneSchedule.length; i++) {
      debugPrint('🎬   Scene $i: ${_sceneSchedule[i].title} (${_sceneSchedule[i].mode})');
    }
  await _cancelSceneTimer(resumeBackground: true);
    final dict = await ThemeDictionary.loadFromAsset(
      'assets/key and themes.txt',
    );
    final theme = dict.findByName(_stageDefinition.themeName);
    setState(() {
      _themeDictionary = dict;
      _stageTheme = theme;
      _currentSceneIndex = 0;
      grid = null;
      _sel = null;
      _selectionNotifier.value = null;
      _clues = const [];
      _revealedClues.clear();
      _sceneActive = false;
      _timeExpired = false;
      _remainingSeconds = null;
      _sceneDurationSeconds = null;
      _dangerHapticTriggered = false;
      _showProgressPath = true; // Show path at game start
    });
    // Don't load puzzle yet - wait for progress path to be dismissed
  }

  Future<void> _loadPuzzle() async {
    debugPrint('🎬 _loadPuzzle called for scene ${_currentSceneIndex + 1} (${_currentScene.title})');
    final dict = _themeDictionary ?? await ThemeDictionary.loadFromAsset(
      'assets/key and themes.txt',
    );
    _themeDictionary = dict;
    final theme = _stageTheme ?? dict.findByName(_stageDefinition.themeName);
    _stageTheme = theme;

    final exclude = _usedAnswers.toList(growable: false);
    var clues = theme.pickClues(10, maxLen: gridSize, exclude: exclude.toSet());

    if (clues.length < 10) {
      debugPrint('⚠️ Only found ${clues.length} unused clues. Used so far: ${_usedAnswers.length} clues');
      debugPrint('⚠️ Used clues: ${_usedAnswers.join(", ")}');

      final totalClues = theme.pickClues(100, maxLen: gridSize);
      debugPrint('⚠️ Theme has ${totalClues.length} total clues available (max length $gridSize)');

      // Gradually relax the "recently used" exclusion so we always get something for Scene 3
      const keepRecentOptions = [10, 6, 3, 0];
      for (final keepRecent in keepRecentOptions) {
        if (_usedAnswers.length <= keepRecent) continue;
        final recentlyUsed = _usedAnswers
            .skip(_usedAnswers.length - keepRecent)
            .toSet();
        clues = theme.pickClues(10, maxLen: gridSize, exclude: recentlyUsed);
        debugPrint('⚠️ Reusing older clues while avoiding $keepRecent most recent. Got ${clues.length} clues');
        if (clues.length >= 10) {
          break;
        }
      }

      if (clues.length < 10) {
        debugPrint('⚠️ Still short (${clues.length}/10). Backfilling with any available clues, even repeats.');
        final fallback = theme.pickClues(10, maxLen: gridSize);
        final existingAnswers = clues.map((c) => c.answer).toSet();

        for (final clue in fallback) {
          if (clues.length >= 10) break;
          if (existingAnswers.add(clue.answer)) {
            clues.add(clue);
          }
        }

        if (clues.length < 10 && fallback.isNotEmpty) {
          // Allow repeats if the theme simply does not have enough unique answers
          var idx = 0;
          while (clues.length < 10) {
            clues.add(fallback[idx % fallback.length]);
            idx++;
          }
        }

        if (clues.length < 10) {
          debugPrint('⚠️ Theme fallback failed to provide 10 clues. Using placeholder entries.');
        }
      }
    }
    
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

    _usedAnswers.addAll(chosen.map((c) => c.answer));

    debugPrint('Selected words: ${chosen.map((c) => '${c.answer}(${c.answer.length})').join(', ')}');

    if (!mounted) {
      return;
    }

    // Reset celebration flag so fireworks can play again
    final gc = context.read<GameController>();
    gc.resetCelebration();
    _resetAutoCompleteSequence();

    setState(() {
      _themeTitle = theme.name.toUpperCase();
      _clues = List<Clue>.from(chosen);
      grid = null;
      _sel = null;
      // Reset game state via ValueNotifiers
      _hintUnlockedNotifier.value = false;
      _selectionNotifier.value = null;
      _revealedClues.clear();
      _remainingSeconds = _currentScene.timeLimit?.inSeconds;
      _sceneDurationSeconds = _currentScene.timeLimit?.inSeconds;
      _timeExpired = false;
      _sceneActive = true;
      _metronomeBeat = 0;
      if (!_isTimedScene) {
        _remainingSeconds = null;
        _sceneDurationSeconds = null;
      }
      _dangerHapticTriggered = false;
    });

    await _cancelSceneTimer(
      resumeBackground: !_isTimedScene,
      controllerOverride: gc,
    );
    if (!mounted) {
      return;
    }
    if (_isTimedScene && _currentScene.timeLimit != null) {
      debugPrint('🎬 Starting timer for timed scene: ${_currentScene.title}');
      await _startSceneTimer(_currentScene.timeLimit!);
    } else {
      debugPrint('🎬 Scene loaded: ${_currentScene.title}, timed: $_isTimedScene');
      setState(() {
        _remainingSeconds = null;
        _sceneDurationSeconds = null;
      });
    }

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
      debugPrint('Using basic fallback grid for Scene ${_currentScene.index}');
      
      // Fallback: Create a simple grid with words placed horizontally
      final grid = List.generate(
        gridSize,
        (_) => List<String>.filled(gridSize, '', growable: false),
        growable: false,
      );
      final rnd = Random();
      int row = 0;
      int col = 0;
      final wordsToPlace = chosen.map((c) => c.answer.toUpperCase()).toList();
      
      for (final word in wordsToPlace) {
        // If word doesn't fit in current row, move to next row
        if (col + word.length > gridSize) {
          row++;
          col = 0;
          if (row >= gridSize) break; // No more rows
        }
        // Place the word
        for (int i = 0; i < word.length && col + i < gridSize; i++) {
          grid[row][col + i] = word[i];
        }
        col += word.length + 1; // Space between words
      }
      
      // Fill remaining empty cells with random letters
      for (int r = 0; r < gridSize; r++) {
        for (int c = 0; c < gridSize; c++) {
          if (grid[r][c].isEmpty) {
            grid[r][c] = String.fromCharCode(65 + rnd.nextInt(26));
          }
        }
      }
      
      puzzle = _Puzzle(grid: grid, words: wordsToPlace);
      debugPrint('Fallback grid created with ${wordsToPlace.length} words');
    }

    // Success: apply puzzle grid and initialize selection controller
    final newGrid = puzzle.grid;
    final targetWords = chosen.map((c) => c.answer.toUpperCase()).toSet();
    
    // Debug: Check what's actually in the grid
    debugPrint('🔍 Grid check - first 4 rows:');
    for (var r = 0; r < 4; r++) {
      final rowContent = newGrid[r].join('');
      final isEmpty = rowContent.replaceAll(' ', '').isEmpty;
      debugPrint('  Row $r: "${newGrid[r].join(' ')}" (empty: $isEmpty)');
    }
    
    setState(() {
      grid = newGrid;
      _sel = SelectionController(
        grid: newGrid,
        gridSize: gridSize,
        targetWords: targetWords,
      );
      // Update selection notifier
      _selectionNotifier.value = _sel;
    });

    _showSceneIntro();
    _schedulePersistGameState();
  }

  Future<void> _cancelSceneTimer({
    bool resumeBackground = false,
    GameController? controllerOverride,
  }) async {
    _sceneTimer?.cancel();
    _sceneTimer = null;
    // Stop countdown music when timer is cancelled
    final gc = controllerOverride;
    if (gc != null) {
      await gc.feedback.stopCountdownMusic(resumeBackground: resumeBackground);
      return;
    }

    if (!mounted) {
      return;
    }

    final controller = context.read<GameController>();
    await controller.feedback
        .stopCountdownMusic(resumeBackground: resumeBackground);
  }

  Future<void> _startSceneTimer(Duration limit) async {
    if (!mounted) return;
    final gc = context.read<GameController>();
    await _cancelSceneTimer(
      resumeBackground: false,
      controllerOverride: gc,
    );
    final totalSeconds = limit.inSeconds;
    if (totalSeconds <= 0) {
      setState(() {
        _remainingSeconds = 0;
      });
      _handleTimeExpired();
      return;
    }
    setState(() {
      _remainingSeconds = totalSeconds;
      _sceneDurationSeconds ??= totalSeconds;
    });
    
    // Start countdown music for timed scenes
    debugPrint('🎬 Starting countdown music for scene: ${_currentScene.title}');
    await gc.feedback.startCountdownMusic();
    
    _sceneTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_sel?.isComplete == true || _timeExpired) {
        timer.cancel();
        return;
      }
      final current = _remainingSeconds ?? 0;
      final next = (current - 1).clamp(0, 6000).toInt();
      setState(() {
        _remainingSeconds = next;
        _metronomeBeat++;
      });
      _playMetronomeTick(next);
      _schedulePersistGameState();
      if (next <= 0) {
        timer.cancel();
        if (!mounted) return;
        _handleTimeExpired();
      }
    });
  }

  void _playMetronomeTick(int remainingSeconds) {
    final gc = context.read<GameController>();
    if (gc.feedback.countdownActive) {
      return;
    }
    if (!_dangerHapticTriggered && remainingSeconds <= 20) {
      _dangerHapticTriggered = true;
      unawaited(gc.feedback.hapticLight());
    }
    
    // Milestone celebrations (positive reinforcement)
    if (remainingSeconds == 60) {
      _showMilestoneFeedback('One Minute Left! 💪');
      unawaited(gc.feedback.hapticMedium());
    } else if (remainingSeconds == 45) {
      _showMilestoneFeedback('45 Seconds - Keep Going! 🎯');
      unawaited(gc.feedback.hapticLight());
    } else if (remainingSeconds == 30) {
      _showMilestoneFeedback('30 Seconds - You Got This! 🔥');
      unawaited(gc.feedback.hapticMedium());
    } else if (remainingSeconds == 15) {
      _showMilestoneFeedback('15 Seconds - Final Push! 🚀');
      unawaited(gc.feedback.hapticMedium());
    }
    
    // Escalating audio patterns based on time remaining
    if (remainingSeconds <= 5) {
      // Critical: Rapid double-tick with haptics
      unawaited(gc.feedback.playTick());
      unawaited(gc.feedback.hapticHeavy());
      Future.delayed(const Duration(milliseconds: 180), () {
        if (!mounted) return;
        unawaited(gc.feedback.playTick());
      });
    } else if (remainingSeconds <= 10) {
      // High urgency: Double-tick with medium haptics
      unawaited(gc.feedback.playTick());
      if (remainingSeconds % 2 == 0) {
        unawaited(gc.feedback.hapticMedium());
      }
      Future.delayed(const Duration(milliseconds: 260), () {
        if (!mounted) return;
        unawaited(gc.feedback.playTick());
      });
    } else if (remainingSeconds <= 30) {
      // Medium urgency: Single tick with light haptics every 3 seconds
      unawaited(gc.feedback.playTick());
      if (remainingSeconds % 3 == 0) {
        unawaited(gc.feedback.hapticLight());
      }
    } else {
      // Normal: Single tick
      unawaited(gc.feedback.playTick());
    }
  }

  void _showMilestoneFeedback(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.deepOrange.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
    );
  }

  void _handleTimeExpired() {
    if (_timeExpired) return;
    final gc = mounted ? context.read<GameController>() : null;
    unawaited(_cancelSceneTimer(
      resumeBackground: true,
      controllerOverride: gc,
    ));
    if (!mounted) return;
    setState(() {
      _timeExpired = true;
      _sceneActive = false;
    });
    unawaited(gc?.onInvalid());
    _schedulePersistGameState(immediate: true);
  }

  Future<void> _restartScene() async {
    if (_startingNewPuzzle) return;
    setState(() {
      _startingNewPuzzle = true;
    });
    await _loadPuzzle();
    if (!mounted) return;
    setState(() {
      _startingNewPuzzle = false;
    });
  }

  Future<void> _advanceScene() async {
    if (_startingNewPuzzle) return;
    debugPrint('🎬 _advanceScene CALLED: stageIndex=$_currentStageIndex, sceneIndex=$_currentSceneIndex, hasMore=$_hasMoreScenes, isFinalScene=$_isFinalScene');
    setState(() {
      _startingNewPuzzle = true;
    });

    // Try to show an interstitial ad between scenes/screens if one is ready.
    // This awaits ad dismissal before continuing; if no ad is cached, it no-ops.
    await InterstitialAdManager.instance.showIfAvailable();
    
    // Check if this is the final scene BEFORE incrementing
    final bool isCurrentlyFinalScene = _isFinalScene;
    debugPrint('🎬 isCurrentlyFinalScene=$isCurrentlyFinalScene (checking before increment)');
    
    if (isCurrentlyFinalScene) {
      // Finished all scenes in this stage, advance to next stage
      final isLastStage = (_currentStageIndex + 1) >= _allStages.length;
      debugPrint('🎬 Is final scene - isLastStage=$isLastStage');
      
      // Mark screen as completed for rating tracking (1-indexed for user-facing numbers)
      final completedScreenNumber = _stageDefinition.index;
      await _ratingService.markScreenCompleted(completedScreenNumber);
      debugPrint('⭐ Marked screen $completedScreenNumber as completed for rating');
      
      if (isLastStage) {
        debugPrint('🎬 Game complete! Looping back to first stage');
        setState(() {
          _currentStageIndex = 0;
          _currentSceneIndex = 0;
        });
      } else {
        debugPrint('🎬 Stage complete, advancing from stage $_currentStageIndex to stage ${_currentStageIndex + 1}');
        setState(() {
          _currentStageIndex++;
          _currentSceneIndex = 0;
        });
      }
      
      // Initialize the new stage before showing progress path
      await _initializeStage();
      
      // Check if we should show rating prompt (after screens 1, 2, or 3)
      if (completedScreenNumber <= 3 && mounted) {
        final shouldShow = await _ratingService.shouldShowRatingPrompt();
        if (shouldShow && mounted) {
          debugPrint('⭐ Showing rating dialog after completing screen $completedScreenNumber');
          await _ratingService.showRatingDialog(context);
        }
      }
      
      // Show progress path when changing stages
      // (_initializeStage already set _showProgressPath = true)
      // Wait for progress path to be dismissed before loading puzzle
      return;
    } else {
      // Not the final scene yet, advance to next scene
      debugPrint('🎬 NOT final scene - Advancing from scene $_currentSceneIndex to scene ${_currentSceneIndex + 1}');
      setState(() {
        _currentSceneIndex++;
      });
      debugPrint('🎬 Scene advanced to: $_currentSceneIndex');
    }
    
    await _loadPuzzle();
    if (!mounted) return;
    setState(() {
      _startingNewPuzzle = false;
    });
  }
  
  Future<void> _onProgressPathComplete(bool resumeGameplay) async {
    if (!mounted) return;

    if (!resumeGameplay) {
      setState(() {
        _showProgressPath = false;
        _startingNewPuzzle = false;
      });
      await Navigator.of(context).maybePop();
      return;
    }

    setState(() {
      _showProgressPath = false;
    });

  final needsPuzzle = grid == null;

    if (needsPuzzle) {
      await _loadPuzzle();
    }

    if (!mounted) return;
    setState(() {
      _startingNewPuzzle = false;
    });
  }

  Future<void> _onScreenSelected(int stageIndex) async {
    // User selected a completed screen to replay from scene 1
    debugPrint('🎬 _onScreenSelected: stageIndex=$stageIndex (before update: current=$_currentStageIndex, scene=$_currentSceneIndex)');
    
    // Clear any saved game state to ensure fresh start
    await _gamePersistence.clear();
    
    setState(() {
      _currentStageIndex = stageIndex;
      _currentSceneIndex = 0;
      // Keep global used answers to minimize repeats across screens; optionally trim most recent to re-allow variety
      if (_usedAnswers.length > 50) {
        // Drop the oldest half to keep memory bounded while still reducing repeats
        final toRemove = _usedAnswers.length ~/ 2;
        _usedAnswers.removeAll(_usedAnswers.take(toRemove).toList());
      }
    });
    
    debugPrint('🎬 _onScreenSelected: After setState - current=$_currentStageIndex, scene=$_currentSceneIndex');
    
    // Initialize the stage without showing progress path (unlike _initializeStage which shows path)
    final dict = await ThemeDictionary.loadFromAsset('assets/key and themes.txt');
    final theme = dict.findByName(_stageDefinition.themeName);
    setState(() {
      _themeDictionary = dict;
      _stageTheme = theme;
    });
    
    debugPrint('🎬 _onScreenSelected: After theme load - current=$_currentStageIndex, scene=$_currentSceneIndex');
    await _loadPuzzle();
    debugPrint('🎬 _onScreenSelected: After _loadPuzzle - current=$_currentStageIndex, scene=$_currentSceneIndex');
  }

  void _showSceneIntro() {
    _clapboardTimer?.cancel();
    if (!mounted) return;

    final sceneIndexLabel = 'SCENE ${_currentScene.index}';
    final sceneTitle = _currentScene.title.toUpperCase();

    debugPrint('🎬 _showSceneIntro: _currentSceneIndex=$_currentSceneIndex, _currentScene.index=${_currentScene.index}, sceneIndexLabel=$sceneIndexLabel');

    setState(() {
      _clapboardLabel = sceneIndexLabel;
      _clapboardSubtitle = sceneTitle;
      _showClapboard = true;
    });

    // Ensure an interstitial is loading for this scene; it'll be shown
    // when the player moves to the next scene/screen.
    final interstitialUnit = Platform.isAndroid
        ? AdsConfig.androidInterstitial
        : AdsConfig.iosInterstitial;
    InterstitialAdManager.instance.load(adUnitId: interstitialUnit);

    final gameController = context.read<GameController>();
    
    // Synchronize sounds and haptics with the clapboard animation
    // Animation: 800ms total with 4 stages
    // Stage 1 (0-160ms): First clap down - sound at 0ms
    // Stage 2 (160-320ms): First clap up - sound at 160ms
    // Stage 3 (320-480ms): Second clap down - sound at 320ms
    // Stage 4 (480-800ms): Second clap up and settle - sound at 480ms
    
    if (gameController.settings.soundEnabled) {
      unawaited(gameController.feedback.playClapboard());
    }
    
    if (gameController.settings.hapticsEnabled) {
      // First clap - medium haptic
      unawaited(gameController.feedback.hapticMedium());
      // Second clap - light haptic
      Future.delayed(const Duration(milliseconds: 320), () {
        if (!mounted || !_showClapboard) return;
        unawaited(gameController.feedback.hapticLight());
      });
    }

    _clapboardTimer = Timer(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      setState(() {
        _showClapboard = false;
      });
    });
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Build simple timer display (no circular ring)
  Widget _buildTimerDisplay(BuildContext context) {
    final remaining = _remainingSeconds!.clamp(0, 5999).toInt();
    final total = _sceneDurationSeconds ?? 90;
    final progress = remaining / total;
    
    // Color transitions: green → yellow → orange → red
    final Color timerColor;
    if (progress > 0.5) {
      // Green to yellow (50% to 100%)
      timerColor = Color.lerp(Colors.yellow.shade600, Colors.green.shade500, (progress - 0.5) * 2)!;
    } else if (progress > 0.2) {
      // Yellow to orange (20% to 50%)
      timerColor = Color.lerp(Colors.orange.shade600, Colors.yellow.shade600, (progress - 0.2) / 0.3)!;
    } else {
      // Orange to red (0% to 20%)
      timerColor = Color.lerp(Colors.red.shade600, Colors.orange.shade600, progress / 0.2)!;
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer, size: 18, color: timerColor),
        const SizedBox(width: 6),
        Text(
          _formatTime(remaining),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  /// Get urgency level based on remaining time
  int _getUrgencyLevel(int remainingSeconds) {
    if (remainingSeconds <= 5) return 3; // Critical
    if (remainingSeconds <= 10) return 2; // High
    if (remainingSeconds <= 30) return 1; // Medium
    return 0; // Normal
  }

  /// Build urgency glow effect around the grid
  Widget _buildUrgencyGlowEffect(int urgencyLevel) {
    Color glowColor;
    double opacity;
    double blurRadius;
    
    switch (urgencyLevel) {
      case 3: // Critical (0-5 seconds)
        glowColor = Colors.red;
        opacity = 0.4;
        blurRadius = 40.0;
        break;
      case 2: // High (6-10 seconds)
        glowColor = Colors.orange;
        opacity = 0.3;
        blurRadius = 30.0;
        break;
      case 1: // Medium (11-30 seconds)
        glowColor = Colors.yellow;
        opacity = 0.2;
        blurRadius = 20.0;
        break;
      default:
        return const SizedBox.shrink();
    }
    
    return TweenAnimationBuilder<double>(
      key: ValueKey(urgencyLevel),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: urgencyLevel == 3 ? 400 : 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        final pulseValue = urgencyLevel == 3 
            ? (sin(_metronomeBeat * pi) * 0.3 + 0.7) // Rapid pulse for critical
            : value;
        
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: opacity * pulseValue),
                blurRadius: blurRadius * pulseValue,
                spreadRadius: 5.0 * pulseValue,
              ),
            ],
          ),
        );
      },
    );
  }

  String get _currentSceneTheme => _stageTheme?.name.toUpperCase() ?? 'BOLLY WORD GRID';

  String _firstLetterHint(Clue clue) {
    final ans = clue.answer;
    if (ans.isEmpty) return clue.label;
    if (ans.length == 1) return ans;
    final remaining = List.filled(ans.length - 1, '•').join(' ');
    return remaining.isEmpty ? ans[0] : '${ans[0]} $remaining';
  }

  Widget _buildClapboardOverlay(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.onSurface;
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          color: Colors.black.withValues(alpha: 0.78),
          alignment: Alignment.center,
          child: TweenAnimationBuilder<double>(
            key: ValueKey<String>('clapboard_${_clapboardLabel}_$_clapboardSubtitle'),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final scale = 0.82 + (0.18 * value);
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              );
            },
            child: _ClapboardCard(
              label: _clapboardLabel,
              subtitle: _clapboardSubtitle,
              themeName: _themeTitle.isEmpty ? _currentSceneTheme : _themeTitle,
              accentColor: themeColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClueChip(
    BuildContext context,
    Clue clue,
    int index,
    SelectionController? controller,
    bool isWide,
    bool isDark,
    Color outline,
    Color onSurface,
  ) {
    final sc = controller;
    final answer = clue.answer.toUpperCase();
    final theme = Theme.of(context);
    final isFound = sc != null && sc.found.any((f) => f.word == answer);
    final color = sc?.wordColors[answer];
    final hasPurchased = _revealedClues.contains(answer);
    final isRevealed = !_isHiddenScene || hasPurchased || isFound;
    final canReveal = _isHiddenScene && !hasPurchased && !isFound && _sceneActive && !_timeExpired;
    final displayLabel = _isHiddenScene
        ? (isFound
            ? clue.label
            : hasPurchased
                ? _firstLetterHint(clue)
                : clue.answer.length.toString())
        : clue.label;

    final textColor = isFound
        ? Colors.white
        : (isRevealed ? theme.colorScheme.onSurface : theme.colorScheme.primary);

    final Color glassBorder = Colors.white.withAlpha(isDark ? 100 : 160);
    final BorderRadius chipRadius = BorderRadius.circular(20);
    final LinearGradient glassGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withAlpha(isDark ? 80 : 220),
        Colors.white.withAlpha(isDark ? 48 : 170),
      ],
    );

    final Color foundBase = (color ?? theme.colorScheme.secondary).withAlpha(230);
    final Color foundBorder = (color ?? outline).withAlpha(200);

    return ClipRRect(
      borderRadius: chipRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: chipRadius,
            onTap: !canReveal
                ? null
                : () {
                    setState(() {
                      _revealedClues.add(answer);
                    });
                    final gc = context.read<GameController>();
                    unawaited(gc.feedback.playClue());
                    _schedulePersistGameState();
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: EdgeInsets.symmetric(
                vertical: isWide ? 8 : 7,
                horizontal: isWide ? 14 : 12,
              ),
              decoration: BoxDecoration(
                gradient: isFound ? null : glassGradient,
                color: isFound ? foundBase : null,
                borderRadius: chipRadius,
                border: Border.all(
                  color: isFound ? foundBorder : glassBorder,
                  width: 1.2,
                ),
                boxShadow: isFound
                    ? [
                        BoxShadow(
                          color: (color ?? Colors.black).withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Text(
                displayLabel,
                style: TextStyle(
                  fontSize: (isWide ? 14 : 11) * 1.05,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  decoration: isFound ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _Puzzle? _generateConstrainedPuzzle(int size, List<String> words) {
    final rnd = Random();
    // Shuffle word list for more random placement order
    final shuffled = List<String>.from(words.map((w) => w.toUpperCase()));
    shuffled.shuffle(rnd);

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

      for (final word in shuffled) {
        // Build and shuffle direction choices for each word
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
        // Shuffle direction choices for each word
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
            if (dir.dr == 0 && dir.dc == 1) {
              placedRight++;
            } else if (dir.dr == 0 && dir.dc == -1) {
              placedLeft++;
            } else if (dir.dr == 1 && dir.dc == 0) {
              placedDown++;
            } else if (dir.dr == -1 && dir.dc == 0) {
              placedUp++;
            } else if (dir.dr == 1 && dir.dc == 1) {
              placedDiagDR++;
            } else if (dir.dr == 1 && dir.dc == -1) {
              placedDiagDL++;
            }
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
        return _Puzzle(grid: grid, words: shuffled);
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
    if (!mounted) return;
    
    // Generate optimized confetti particles
    _confetti = OptimizedConfetti.createParticles(MediaQuery.of(context).size);
    _showConfettiNotifier.value = true;
    
    // Start animation
    _confettiController.reset();
    _confettiController.forward();
    
    // Hide confetti after animation completes
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _showConfettiNotifier.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show progress path screen if flag is set
    if (_showProgressPath) {
      return ProgressPathScreen(
        allStages: _allStages,
        currentStageIndex: _currentStageIndex,
        currentSceneIndex: _currentSceneIndex,
        onComplete: _onProgressPathComplete,
        onScreenSelected: _onScreenSelected,
      );
    }
    
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900; // tablet breakpoint
    final settings = context.watch<FeedbackSettings>();
    final isDark = settings.theme == AppTheme.kashyap;

  return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: AnimatedRotation(
          duration: const Duration(milliseconds: 300),
          turns: 0.0, // Can animate on press if needed
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Consumer<WalletService>(
          builder: (context, wallet, child) => _GoldenTicket(score: wallet.tickets),
        ),
        centerTitle: true,
        actions: [
          Consumer<WalletService>(
            builder: (context, wallet, child) {
              final score = wallet.tickets;
              final settings = context.watch<FeedbackSettings>();
              final canUseHints = settings.hintsEnabled && score >= 20 && _sel != null && _sceneActive && !_timeExpired;
                final theme = Theme.of(context);
                final Color buttonColor = canUseHints
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.surfaceContainerHighest;
              final Color iconColor = canUseHints
                  ? theme.colorScheme.onSecondary
                  : theme.colorScheme.onSurface.withAlpha(150);

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Material(
                  color: buttonColor,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: !canUseHints
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
                              _changeScore(-15, allowHintReminder: false);
                              sc.showHintAt(start, durationMs: 1000);
                              _schedulePersistGameState();
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Icon(
                        Icons.question_mark,
                        size: 20,
                        color: iconColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
        toolbarHeight: isWide ? 76 : 68,
      ),
      body: PopScope(
        canPop: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image extending behind app bar
            Positioned.fill(
              child: Image.asset(
                isDark ? 'assets/Options_Dark.png' : 'assets/Options_Light.png',
                fit: BoxFit.cover,
              ),
            ),
            // Subtle backdrop blur for depth
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black.withAlpha(13),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _gameScrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    physics: _scrollLocked
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // Theme name bar styled as glass surface
                        Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + (isWide ? 76 : 68),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: GlassSurface(
                      blurAmount: 20,
                      borderRadius: BorderRadius.zero,
                      backgroundGradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withAlpha(isDark ? 38 : 140),
                          Colors.white.withAlpha(isDark ? 22 : 105),
                        ],
                      ),
                      borderColor: Colors.white.withAlpha(isDark ? 64 : 120),
                      elevationColor: isDark
                          ? Colors.black.withValues(alpha: 0.20)
                          : Colors.black.withValues(alpha: 0.12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: Text(
                                      _sceneHeaderLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (_isTimedScene && _remainingSeconds != null) ...[
                              const SizedBox(height: 8),
                              _buildTimerDisplay(context),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                        // Key box with chips - transparent layout
                        Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Rebuild the clue chips whenever selection/found state changes
                      if (_sel != null)
                        AnimatedBuilder(
                          animation: _sel!,
                          builder: (context, _) {
                            final sc = _sel;
                            return Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: _clues.asMap().entries.map((entry) {
                                return _buildClueChip(
                                  context,
                                  entry.value,
                                  entry.key,
                                  sc,
                                  isWide,
                                  isDark,
                                  outline,
                                  onSurface,
                                );
                              }).toList(),
                            );
                          },
                        )
                      else
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: _clues.asMap().entries.map((entry) {
                            return _buildClueChip(
                              context,
                              entry.value,
                              entry.key,
                              null,
                              isWide,
                              isDark,
                              outline,
                              onSurface,
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                        // Selection preview listens directly to SelectionController changes
                        if (_sel != null)
                          AnimatedBuilder(
                            animation: _sel!,
                            builder: (context, _) {
                              if (!_sel!.hasActive || _sel!.activeString.isEmpty) {
                                return const SizedBox(height: 35);
                              }
                              return Padding(
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
                                              color: Colors.black.withValues(alpha: 0.3),
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
                              );
                            },
                          )
                        else
                          const SizedBox(height: 35),
                        const SizedBox(height: 16),
                        // Grid container - uses LayoutBuilder to size based on available width
                        LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate grid size based on screen width with padding
                    final availableWidth = constraints.maxWidth - 32; // 16px padding on each side
                    final calculatedGridSize = availableWidth.clamp(280.0, 500.0);
                    
                    return Center(
                      child: SizedBox(
                        width: calculatedGridSize,
                        height: calculatedGridSize,
                        child: AspectRatio(
                      aspectRatio: 1,
                      child: LayoutBuilder(
                        builder: (context, inner) {
                          if (_sel == null || grid == null) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          // Calculate urgency level for visual effects
                          final urgencyLevel = _isTimedScene && _remainingSeconds != null 
                              ? _getUrgencyLevel(_remainingSeconds!)
                              : 0;
                          
                          // Listen directly to SelectionController so grid and painter update on drag
                          return AnimatedBuilder(
                            animation: _sel!,
                            builder: (context, _) {
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Urgency glow effect
                                  if (urgencyLevel > 0)
                                    Positioned.fill(
                                      child: _buildUrgencyGlowEffect(urgencyLevel),
                                    ),
                                  Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      margin: const EdgeInsets.all(12),
                                      decoration: const BoxDecoration(),
                                      clipBehavior: Clip.none,
                                      child: LayoutBuilder(
                                        builder: (context, inner2) {
                                          final boardSize = inner2.biggest.shortestSide;
                                          final gridConstraints = BoxConstraints.tight(Size.square(boardSize));
                                          
                                          return SizedBox(
                                            width: boardSize,
                                            height: boardSize,
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onPanDown: (_) => _handleGridPanDown(),
                                              onPanStart: (d) => _onGridPanStart(d, gridConstraints),
                                              onPanUpdate: (d) => _onGridPanUpdate(d, gridConstraints),
                                              onPanEnd: _onPanEnd,
                                              onPanCancel: () => _setScrollLocked(false),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                clipBehavior: Clip.none,
                                                children: [
                                                  // Background for the entire grid
                                                  Container(
                                                    color: surface,
                                                  ),
                                                  // Grid cells with transparent backgrounds
                                                  RepaintBoundary(
                                                    child: GridView.builder(
                                                      physics: const NeverScrollableScrollPhysics(),
                                                      padding: EdgeInsets.zero,
                                                      shrinkWrap: true,  // Ensure grid doesn't take extra space
                                                      itemCount: gridSize * gridSize,
                                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                        crossAxisCount: gridSize,
                                                        mainAxisSpacing: 0,  // No spacing between rows
                                                        crossAxisSpacing: 0,  // No spacing between columns
                                                      ),
                                                      itemBuilder: (context, index) {
                                                        final row = index ~/ gridSize;
                                                        final col = index % gridSize;
                                                        final sc = _sel!;
                                                        final cellOffset = Offset(row.toDouble(), col.toDouble());
                                                        final inSelected = sc.activePath.contains(cellOffset);
                                                        final inFound = _isInFoundPaths(cellOffset, sc);
                                                        final tile = boardSize / gridSize;
                                                        final fontSize = ((tile * 0.55).clamp(14.0, isWide ? 48.0 : 36.0)) * 1.0;
                                                        
                                                        return AnimatedScale(
                                                          duration: const Duration(milliseconds: 100),
                                                          scale: inSelected ? 1.08 : 1.0,
                                                          child: Container(
                                                            margin: const EdgeInsets.all(2.5),
                                                            decoration: BoxDecoration(
                                                              color: Colors.transparent,  // Transparent so film reel shows through
                                                              borderRadius: BorderRadius.circular(inSelected || inFound ? 10 : 8),
                                                            ),
                                                            child: Align(
                                                                alignment: const Alignment(0.0, 0.0),
                                                                child: Text(
                                                                  grid![row][col],
                                                                  style: TextStyle(
                                                                    fontSize: fontSize,
                                                                    fontWeight: FontWeight.normal,
                                                                    color: onSurface,  // Always use theme color (black in light theme, white in dark)
                                                                  ),
                                                                ),
                                                              ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  // Film reel overlay ABOVE the grid cells
                                                  IgnorePointer(
                                                    child: RepaintBoundary(
                                                      child: CustomPaint(
                                                        painter: FilmReelPainter(
                                                          cellSize: boardSize / gridSize,
                                                          found: _sel!.found,
                                                          activePath: _sel!.activePath,
                                                          activeColor: _sel!.activeColor,
                                                          surfaceColor: Colors.transparent,
                                                          debug: false,
                                                          repaint: Listenable.merge([
                                                            _sel!,
                                                            ..._sel!.found.map((fp) => fp.progress),
                                                          ]),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Grid overlay with horizontal and vertical lines
                                                  RepaintBoundary(
                                                    child: CustomPaint(
                                                      painter: _GridPainter(
                                                        gridSize: gridSize,
                                                        cellSize: boardSize / gridSize,
                                                        lineColor: Colors.grey.withValues(alpha: 0.4),
                                                        lineWidth: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _showConfettiNotifier,
                                    builder: (context, showConfetti, _) {
                                      if (!showConfetti) {
                                        return const SizedBox.shrink();
                                      }
                                      return OptimizedConfettiLayer(
                                        particles: _confetti,
                                        animation: _confettiAnimation,
                                      );
                                    },
                                  ),
                                  if (_timeExpired)
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        alignment: Alignment.center,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              "Time's up!",
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            FilledButton.icon(
                                              onPressed: _startingNewPuzzle ? null : _restartScene,
                                              icon: const Icon(Icons.refresh),
                                              label: Text(_startingNewPuzzle ? 'Loading…' : 'Retry scene'),
                                              style: FilledButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                                                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else if (_sel?.isComplete == true)
                                    Positioned.fill(
                                      child: Container(
                                        color: Colors.black.withValues(alpha: 0.55),
                                        alignment: Alignment.center,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_isFinalScene && (_currentStageIndex + 1) >= _allStages.length) ...[
                                              const Text(
                                                'All screens complete! 🎉',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                            ] else
                                              const SizedBox(height: 8),
                                            FilledButton.icon(
                                              onPressed: _startingNewPuzzle ? null : _advanceScene,
                                              icon: Icon(
                                                (_isFinalScene && (_currentStageIndex + 1) >= _allStages.length)
                                                    ? Icons.replay
                                                    : Icons.arrow_forward,
                                              ),
                                              label: Text(
                                                _startingNewPuzzle
                                                    ? 'Loading…'
                                                    : (_isFinalScene
                                                        ? ((_currentStageIndex + 1) >= _allStages.length
                                                            ? 'Play again'
                                                            : 'Next screen')
                                                        : 'Next scene'),
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
                    );
                  },
                ),
                      ],
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
            if (_showClapboard)
              _buildClapboardOverlay(context),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Best-effort cleanup for any cached interstitials
    // (safe to fire-and-forget during widget disposal)
    InterstitialAdManager.instance.dispose();
    _bannerAd?.dispose();
    GameController? controller;
    try {
      controller = context.read<GameController>();
    } catch (_) {
      controller = null;
    }
    unawaited(_cancelSceneTimer(controllerOverride: controller));
    // Release animation controller back to pool
    AnimationManager().releaseController(_confettiController, id: 'confetti');
    // Dispose ValueNotifiers
    _hintUnlockedNotifier.dispose(); 
    _showConfettiNotifier.dispose();
    _selectionNotifier.dispose();
    _saveDebounce?.cancel();
    _clapboardTimer?.cancel();
    _autoCompleteResetTimer?.cancel();
      _gameScrollController.dispose();
    super.dispose();
  }
}

class _ClapboardCard extends StatefulWidget {
  const _ClapboardCard({
    required this.label,
    required this.subtitle,
    required this.themeName,
    required this.accentColor,
  });

  final String label;
  final String subtitle;
  final String themeName;
  final Color accentColor;

  @override
  State<_ClapboardCard> createState() => _ClapboardCardState();
}

class _ClapboardCardState extends State<_ClapboardCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _clapController;
  late Animation<double> _clapAnimation;

  @override
  void initState() {
    super.initState();
    _clapController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _clapAnimation = TweenSequence<double>([
      // Quick clap down
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.4)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      // Quick clap up
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.4, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      // Second clap down
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.4)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      // Second clap up and settle
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.4, end: -0.09)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_clapController);

    // Start the clapping animation
    _clapController.forward();
  }

  @override
  void dispose() {
    _clapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = min(MediaQuery.of(context).size.width * 0.82, 360.0);

    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 42),
            padding: const EdgeInsets.fromLTRB(28, 56, 28, 30),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 28,
                  spreadRadius: 4,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 120,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.themeName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: -6,
            child: AnimatedBuilder(
              animation: _clapAnimation,
              builder: (context, child) => _ClapboardHeader(
                rotationAngle: _clapAnimation.value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClapboardHeader extends StatelessWidget {
  const _ClapboardHeader({required this.rotationAngle});

  final double rotationAngle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 26,
            top: 14,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Transform.rotate(
              angle: rotationAngle,
              origin: const Offset(-50, -10),
              child: Container(
                height: 62,
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Row(
                    children: List.generate(8, (index) {
                      final isLight = index.isOdd;
                      return Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isLight ? Colors.white : const Color(0xFF111111),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.gridSize,
    required this.cellSize,
    required this.lineColor,
    required this.lineWidth,
  });

  final int gridSize;
  final double cellSize;
  final Color lineColor;
  final double lineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    for (var i = 0; i <= gridSize; i++) {
      final offset = i * cellSize;
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, offset),
        Offset(size.width, offset),
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

/// Optimized confetti layer that uses efficient animation patterns
class OptimizedConfettiLayer extends StatelessWidget {
  const OptimizedConfettiLayer({
    super.key,
    required this.particles,
    required this.animation,
  });

  final List<ConfettiParticle> particles;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: OptimizedAnimatedBuilder(
        animation: animation,
        builder: (context, progress, child) {
          return Stack(
            children: particles.map((particle) {
              final position = particle.getPosition(progress);
              final rotation = particle.getRotation(progress);
              final opacity = (1.0 - progress).clamp(0.0, 1.0);

              return Positioned(
                left: position.dx,
                top: position.dy,
                child: Transform.rotate(
                  angle: rotation * 3.14159 / 180,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: particle.size,
                      height: particle.size,
                      decoration: BoxDecoration(
                        color: particle.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _GoldenTicket extends StatelessWidget {
  const _GoldenTicket({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    const ticketGradient = LinearGradient(
      colors: [
        Color(0xFFFFF5CC), // Light cream
        Color(0xFFFFE8A3), // Golden yellow
        Color(0xFFFFF5CC), // Light cream
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    
    const sheen = LinearGradient(
      colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
      begin: Alignment.topLeft,
      end: Alignment(0.4, 0.4),
    );

    const double baseScale = 0.6; // Compact but legible ticket scale
    const double lengthFactor = 1.25; // Extend ticket length by 25%
    const double baseWidth = 160;
    const double baseHeight = 80; // Increased from 70 to support 4-digit scores
    const double baseCornerRadius = 6;
    const double baseNotchRadius = 12;
    const double basePerforationOffset = 28;
    const double baseHeaderFont = 10;
    const double baseScoreFont = 28;
    const double baseLabelFont = 8;
    const double baseSerialFont = 8;
    const double baseHorizontalGap = 6;
    const double baseVerticalGap = 4; // Increased from 2 to provide more spacing

    return LayoutBuilder(
      builder: (context, constraints) {
        final double desiredWidth = baseWidth * lengthFactor * baseScale;
        final double maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : desiredWidth;
        final double scaleFactor = desiredWidth > 0
            ? baseScale * min(1.0, maxWidth / desiredWidth)
            : baseScale;

        final double width = (baseWidth * lengthFactor * scaleFactor).ceilToDouble();
        final double height = (baseHeight * scaleFactor).ceilToDouble();
        final double cornerR = baseCornerRadius * scaleFactor;
        final double notchR = baseNotchRadius * scaleFactor;

        final double headerFontSize = baseHeaderFont * scaleFactor;
        final double scoreFontSize = baseScoreFont * scaleFactor;
        final double labelFontSize = baseLabelFont * scaleFactor;
        final double serialFontSize = baseSerialFont * scaleFactor;
        final double headerLetterSpacing = max(0.5, 2 * scaleFactor);
        final double labelLetterSpacing = max(0.3, 1 * scaleFactor);
        final double serialLetterSpacing = max(0.4, 1 * scaleFactor);
        final double horizontalGap = max(3.0, baseHorizontalGap * scaleFactor);
        final double verticalGap = max(1.0, baseVerticalGap * scaleFactor);
        final double perforationOffset = basePerforationOffset * scaleFactor * lengthFactor;
        final double perforationWidth = max(1.0, 2 * scaleFactor);
        final Offset shadowOffset = Offset(1 * scaleFactor, 1 * scaleFactor);
        final String ticketLabel = score == 1 ? 'TICKET' : 'TICKETS';

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Shadow layer
              Transform.translate(
                offset: Offset(0, 2 * scaleFactor),
                child: ClipPath(
                  clipper: _TicketClipper(cornerRadius: cornerR, notchRadius: notchR),
                  child: Container(
                    width: width,
                    height: height,
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
              ),

              // Ticket shape with gradient
              ClipPath(
                clipper: _TicketClipper(cornerRadius: cornerR, notchRadius: notchR),
                child: Container(
                  width: width,
                  height: height,
                  decoration: const BoxDecoration(
                    gradient: ticketGradient,
                  ),
                  child: Stack(
                    children: [
                      // Vintage pattern background
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _TicketPatternPainter(),
                        ),
                      ),

                      // Content
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // "ADMIT ONE" text
                            Text(
                              'ADMIT ONE',
                              style: TextStyle(
                                fontSize: headerFontSize,
                                fontWeight: FontWeight.w800,
                                letterSpacing: headerLetterSpacing,
                                color: Colors.brown.shade800,
                              ),
                            ),
                            SizedBox(height: verticalGap),
                            // Score display
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '$score',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: scoreFontSize,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.brown.shade900,
                                    shadows: [
                                      Shadow(
                                        offset: shadowOffset,
                                        blurRadius: 0,
                                        color: Colors.brown.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: horizontalGap),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'GOLDEN',
                                      style: TextStyle(
                                        fontSize: labelFontSize,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: labelLetterSpacing,
                                        height: 1,
                                        color: Colors.brown.shade700,
                                      ),
                                    ),
                                    Text(
                                      ticketLabel,
                                      style: TextStyle(
                                        fontSize: labelFontSize,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: labelLetterSpacing,
                                        height: 1,
                                        color: Colors.brown.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: verticalGap),
                            // Serial number
                            Text(
                              'No. ${(score * 1337 % 999999).toString().padLeft(6, '0')}',
                              style: TextStyle(
                                fontSize: serialFontSize,
                                fontWeight: FontWeight.w500,
                                color: Colors.brown.shade600,
                                letterSpacing: serialLetterSpacing,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Perforated edge lines
                      Positioned(
                        left: perforationOffset,
                        top: 0,
                        bottom: 0,
                        child: CustomPaint(
                          size: Size(perforationWidth, double.infinity),
                          painter: _PerforatedLinePainter(),
                        ),
                      ),
                      Positioned(
                        right: perforationOffset,
                        top: 0,
                        bottom: 0,
                        child: CustomPaint(
                          size: Size(perforationWidth, double.infinity),
                          painter: _PerforatedLinePainter(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Sheen overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipPath(
                    clipper: _TicketClipper(cornerRadius: cornerR, notchRadius: notchR),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: sheen,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TicketClipper extends CustomClipper<Path> {
  final double cornerRadius;
  final double notchRadius;
  const _TicketClipper({required this.cornerRadius, required this.notchRadius});

  @override
  Path getClip(Size size) {
    final r = cornerRadius;
    final nr = notchRadius;
    final w = size.width;
    final h = size.height;
    
    final path = Path();
    
    // Start at top-left corner after radius
    path.moveTo(r, 0);
    
    // Top edge with scalloped pattern
    const scallops = 8;
    final scW = (w - 2 * r) / scallops;
    for (int i = 0; i < scallops; i++) {
      final x1 = r + i * scW;
      final x2 = x1 + scW / 2;
      final x3 = x1 + scW;
      path.quadraticBezierTo(x2, -2, x3, 0);
    }
    
    // Top-right corner
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r));
    
    // Right edge down to notch start
    path.lineTo(w, h / 2 - nr);
    
    // Right notch (larger semi-circle inward)
    path.arcToPoint(
      Offset(w, h / 2 + nr),
      radius: Radius.circular(nr),
      clockwise: false,
    );
    
    // Right edge to bottom-right corner
    path.lineTo(w, h - r);
    
    // Bottom-right corner
    path.arcToPoint(Offset(w - r, h), radius: Radius.circular(r));
    
    // Bottom edge with scalloped pattern
    for (int i = scallops - 1; i >= 0; i--) {
      final x1 = r + (i + 1) * scW;
      final x2 = x1 - scW / 2;
      final x3 = x1 - scW;
      path.quadraticBezierTo(x2, h + 2, x3, h);
    }
    
    // Bottom-left corner
    path.arcToPoint(Offset(0, h - r), radius: Radius.circular(r));
    
    // Left edge up to notch start
    path.lineTo(0, h / 2 + nr);
    
    // Left notch
    path.arcToPoint(
      Offset(0, h / 2 - nr),
      radius: Radius.circular(nr),
      clockwise: false,
    );
    
    // Left edge to top-left corner
    path.lineTo(0, r);
    
    // Top-left corner
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
    
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _TicketClipper oldClipper) {
    return oldClipper.cornerRadius != cornerRadius || oldClipper.notchRadius != notchRadius;
  }
}

// Ticket pattern painter for vintage look
class _TicketPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown.withValues(alpha: 0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    // Draw subtle diagonal lines for vintage texture
    const spacing = 4.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Perforated line painter
class _PerforatedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    
    const dashHeight = 3.0;
    const dashSpace = 2.0;
    double y = 0;
    
    while (y < size.height) {
      canvas.drawLine(
        Offset(0, y),
        Offset(0, y + dashHeight),
        paint,
      );
      y += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
