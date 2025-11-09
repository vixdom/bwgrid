import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_themes.dart';
import '../models/feedback_settings.dart';
import '../models/stage_scene.dart';
import 'glass_surface.dart';

/// Displays the player's progress through all screens/stages
/// Shows completed, current, and upcoming screens with animated transitions
/// Allows selecting any completed screen to replay from scene 1
class ProgressPathScreen extends StatefulWidget {
  const ProgressPathScreen({
    super.key,
    required this.allStages,
    required this.currentStageIndex,
    required this.currentSceneIndex,
    required this.onComplete,
    this.onScreenSelected,
  });

  final List<StageDefinition> allStages;
  final int currentStageIndex;
  final int currentSceneIndex;
  final VoidCallback onComplete;
  final void Function(int stageIndex)? onScreenSelected;

  @override
  State<ProgressPathScreen> createState() => _ProgressPathScreenState();
}

class _ProgressPathScreenState extends State<ProgressPathScreen>
  with TickerProviderStateMixin {
  late AnimationController _controller;
  bool _showDetails = false;
  late final List<GlobalKey> _cardKeys;
  late final AnimationController _pulseController;
  late final AnimationController _marqueeController;
  late final AnimationController _shimmerController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _marqueeAnimation;
  late final Animation<double> _shimmerAnimation;
  bool _isUnlockShimmerVisible = false;

  @override
  void didUpdateWidget(covariant ProgressPathScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStageIndex != widget.currentStageIndex) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToCurrentStage(),
      );
      if (widget.currentStageIndex > oldWidget.currentStageIndex) {
        _startUnlockShimmer();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _cardKeys = List<GlobalKey>.generate(
      widget.allStages.length,
      (_) => GlobalKey(),
    );
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _marqueeController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _marqueeAnimation = Tween<double>(begin: -1.2, end: 1.2).animate(
      CurvedAnimation(parent: _marqueeController, curve: Curves.linear),
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );

    _shimmerAnimation = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    );

    _shimmerController.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        setState(() => _isUnlockShimmerVisible = false);
        _shimmerController.reset();
      }
    });

    // Start animation after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _controller.forward();
        setState(() => _showDetails = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentStage();
        });
      }
    });
  }

  void _startUnlockShimmer() {
    if (!_shimmerController.isAnimating) {
      setState(() => _isUnlockShimmerVisible = true);
      _shimmerController.forward(from: 0);
    }
  }

  void _scrollToCurrentStage() {
    if (!mounted || _cardKeys.isEmpty) return;
    final index = widget.currentStageIndex.clamp(0, _cardKeys.length - 1);
    final context = _cardKeys[index].currentContext;
    if (context == null) {
      // Try again on next frame if layout not ready
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToCurrentStage(),
      );
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.35,
    );
  }

  void _dismissScreen({int? selectedStageIndex}) async {
    if (_controller.isAnimating) return;
    await _controller.reverse();
    if (mounted) {
      if (selectedStageIndex != null && widget.onScreenSelected != null) {
        widget.onScreenSelected!(selectedStageIndex);
      }
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    _marqueeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FeedbackSettings>();
    final isDarkTheme = settings.theme == AppTheme.kashyap;
    final backgroundImage = isDarkTheme
        ? 'assets/Options_Dark.png'
        : 'assets/Options_Light.png';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(backgroundImage),
            fit: BoxFit.cover,
            opacity: isDarkTheme ? 0.2 : 0.18,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDarkTheme),

              // Scrollable screens list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  itemCount:
                      widget.allStages.length +
                      1, // +1 for "coming soon" message
                  itemBuilder: (context, index) {
                    if (index < widget.allStages.length) {
                      return _buildScreenCard(index);
                    } else {
                      // "More screens coming soon" message after last screen
                      return _buildComingSoonCard();
                    }
                  },
                ),
              ),

              // Play button at bottom
              if (_showDetails)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _dismissScreen,
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: Text(
                        'Play Screen ${widget.currentStageIndex + 1}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 20,
                        ),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkTheme) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(24),
        backgroundGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(isDarkTheme ? 0.35 : 0.48),
            Colors.white.withOpacity(isDarkTheme ? 0.12 : 0.18),
          ],
        ),
        borderColor: Colors.white.withOpacity(isDarkTheme ? 0.38 : 0.44),
        elevationColor: Colors.black.withOpacity(isDarkTheme ? 0.36 : 0.22),
        blurAmount: 26,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(isDarkTheme ? 0.2 : 0.28),
                  border: Border.all(
                    color: Colors.white.withOpacity(isDarkTheme ? 0.38 : 0.46),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  Icons.movie_creation_outlined,
                  size: 26,
                  color: onSurface.withOpacity(isDarkTheme ? 0.8 : 0.72),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 30,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Text(
                            'BollyWord Multiplex',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: onSurface.withOpacity(
                                isDarkTheme ? 0.92 : 0.86,
                              ),
                              letterSpacing: 1.1,
                            ),
                          ),
                          IgnorePointer(
                            ignoring: true,
                            child: AnimatedBuilder(
                              animation: _marqueeAnimation,
                              builder: (context, child) {
                                final alignmentX = _marqueeAnimation.value;
                                return Align(
                                  alignment: Alignment(alignmentX, 0),
                                  child: FractionallySizedBox(
                                    widthFactor: 0.35,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.white.withOpacity(0.0),
                                            Colors.white.withOpacity(
                                              isDarkTheme ? 0.25 : 0.35,
                                            ),
                                            Colors.white.withOpacity(0.0),
                                          ],
                                          stops: const [0.0, 0.5, 1.0],
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
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pick a screen and lights, camera, action!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: onSurface.withOpacity(isDarkTheme ? 0.7 : 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreenCard(int index) {
    final stage = widget.allStages[index];
    final isPast = index < widget.currentStageIndex;
    final isCurrent = index == widget.currentStageIndex;
    final isFuture = index > widget.currentStageIndex;
    final isClickable =
        isPast || isCurrent; // Can click completed or current screen
    final theme = Theme.of(context);
    final isDarkTheme = theme.brightness == Brightness.dark;

    // Calculate completed scenes for this stage
    int completedScenes = 0;
    if (isPast) {
      completedScenes = 3; // All scenes completed
    } else if (isCurrent) {
      completedScenes = widget.currentSceneIndex;
    }

    final gradientColors = isCurrent
        ? <Color>[
            Colors.white.withOpacity(isDarkTheme ? 0.58 : 0.7),
            theme.colorScheme.primary.withOpacity(isDarkTheme ? 0.26 : 0.2),
            Colors.white.withOpacity(isDarkTheme ? 0.22 : 0.34),
          ]
        : isPast
        ? <Color>[
            Colors.white.withOpacity(isDarkTheme ? 0.42 : 0.56),
            Colors.white.withOpacity(isDarkTheme ? 0.18 : 0.26),
            Colors.white.withOpacity(isDarkTheme ? 0.08 : 0.16),
          ]
        : <Color>[
            Colors.white.withOpacity(isDarkTheme ? 0.28 : 0.4),
            Colors.white.withOpacity(isDarkTheme ? 0.12 : 0.18),
            Colors.white.withOpacity(isDarkTheme ? 0.05 : 0.1),
          ];

    final borderOpacity = isCurrent
        ? (isDarkTheme ? 0.48 : 0.54)
        : isPast
        ? (isDarkTheme ? 0.32 : 0.4)
        : (isDarkTheme ? 0.2 : 0.26);

    final shadowOpacity = isCurrent
        ? (isDarkTheme ? 0.55 : 0.3)
        : isPast
        ? (isDarkTheme ? 0.4 : 0.24)
        : (isDarkTheme ? 0.3 : 0.18);

    final titleColor = isDarkTheme
        ? Colors.white.withOpacity(isCurrent ? 0.95 : 0.88)
        : Colors.black.withOpacity(isCurrent ? 0.92 : 0.85);

    final subtitleColor = isDarkTheme
        ? Colors.white.withOpacity(isCurrent ? 0.8 : 0.72)
        : Colors.black.withOpacity(isCurrent ? 0.7 : 0.62);

    final inactiveDotColor = isDarkTheme
        ? Colors.white.withOpacity(0.22)
        : Colors.black.withOpacity(0.12);

    final totalScenes = stage.scenes.length;
    int sceneNumber;
    if (isPast) {
      sceneNumber = totalScenes;
    } else if (isCurrent) {
      sceneNumber = widget.currentSceneIndex + 1;
    } else {
      sceneNumber = 1;
    }

    if (sceneNumber < 1) {
      sceneNumber = 1;
    } else if (sceneNumber > totalScenes) {
      sceneNumber = totalScenes;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        );
      },
      child: GestureDetector(
        key: _cardKeys[index],
        onTap: isClickable
            ? () {
                if (isPast) {
                  _showReplayConfirmation(index);
                } else {
                  _dismissScreen();
                }
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _buildAnimatedCard(
            index: index,
            gradientColors: gradientColors,
            borderOpacity: borderOpacity,
            shadowOpacity: shadowOpacity,
            isCurrent: isCurrent,
            isPast: isPast,
            isFuture: isFuture,
            titleColor: titleColor,
            subtitleColor: subtitleColor,
            inactiveDotColor: inactiveDotColor,
            stage: stage,
            completedScenes: completedScenes,
            isDarkTheme: isDarkTheme,
            sceneNumber: sceneNumber,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCard({
    required int index,
    required List<Color> gradientColors,
    required double borderOpacity,
    required double shadowOpacity,
    required bool isCurrent,
    required bool isPast,
    required bool isFuture,
    required Color titleColor,
    required Color subtitleColor,
    required Color inactiveDotColor,
    required StageDefinition stage,
    required int completedScenes,
    required bool isDarkTheme,
    required int sceneNumber,
  }) {
    final theme = Theme.of(context);
    final shimmerActive =
        isPast &&
        (index == widget.currentStageIndex - 1) &&
        _isUnlockShimmerVisible;

    Widget card = GlassSurface(
      borderRadius: BorderRadius.circular(24),
      backgroundGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
      ),
      borderColor: Colors.white.withOpacity(borderOpacity),
      elevationColor: Colors.black.withOpacity(shadowOpacity),
      blurAmount: 20,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Screen image with number overlay
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/screen_cropped.png'),
                          fit: BoxFit.cover,
                          opacity: 0.8,
                        ),
                      ),
                    ),
                    if (isPast)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF27C26A,
                          ).withOpacity(isDarkTheme ? 0.9 : 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 28,
                        ),
                      )
                    else
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? theme.colorScheme.primary.withOpacity(0.9)
                              : theme.colorScheme.onSurface.withOpacity(
                                  isDarkTheme ? 0.4 : 0.18,
                                ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 16),

                // Screen info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Screen ${index + 1} Now showing',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${stage.themeName} Scene $sceneNumber',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Three dots for scene progress
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (sceneIndex) {
                          final isSceneCompleted = sceneIndex < completedScenes;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSceneCompleted
                                    ? (isCurrent
                                          ? theme.colorScheme.primary
                                          : const Color(0xFF27C26A).withOpacity(
                                              isDarkTheme ? 0.9 : 0.75,
                                            ))
                                    : inactiveDotColor,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                // Lock icon for future screens or replay icon for completed
                if (isFuture)
                  Icon(
                    Icons.lock_outline,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                    size: 28,
                  )
                else if (isPast)
                  Icon(
                    Icons.replay,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                    size: 28,
                  ),
              ],
            ),
          ),
          if (shimmerActive)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: IgnorePointer(
                  ignoring: true,
                  child: AnimatedBuilder(
                    animation: _shimmerAnimation,
                    builder: (context, child) {
                      if (!_isUnlockShimmerVisible) {
                        return const SizedBox.shrink();
                      }
                      final alignmentX = (_shimmerAnimation.value * 2) - 1;
                      return Align(
                        alignment: Alignment(alignmentX, 0),
                        child: FractionallySizedBox(
                          widthFactor: 0.4,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withOpacity(0.0),
                                  Colors.white.withOpacity(
                                    isDarkTheme ? 0.18 : 0.28,
                                  ),
                                  Colors.white.withOpacity(0.0),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (isCurrent) {
      card = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _pulseAnimation.value, child: child);
        },
        child: card,
      );
    }

    return card;
  }

  Future<void> _showReplayConfirmation(int stageIndex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replay Screen?'),
        content: Text(
          'Do you want to replay Screen ${stageIndex + 1} from Scene 1?\n\n'
          'Your current progress will be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replay'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _dismissScreen(selectedStageIndex: stageIndex);
    }
  }

  Widget _buildComingSoonCard() {
    final theme = Theme.of(context);
    final isDarkTheme = theme.brightness == Brightness.dark;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (widget.allStages.length * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(24),
          backgroundGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(isDarkTheme ? 0.38 : 0.55),
              Colors.white.withOpacity(isDarkTheme ? 0.14 : 0.22),
            ],
          ),
          borderColor: Colors.white.withOpacity(isDarkTheme ? 0.26 : 0.32),
          elevationColor: Colors.black.withOpacity(isDarkTheme ? 0.32 : 0.18),
          blurAmount: 18,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.movie_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'More screens coming soon',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'New challenges and themes on the way!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
