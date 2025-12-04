import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stage_scene.dart';
import '../models/feedback_settings.dart';
import '../constants/app_themes.dart';
import '../services/game_persistence.dart';
import '../widgets/glass_surface.dart';

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
  final void Function(bool resumeGameplay) onComplete;
  final void Function(int stageIndex)? onScreenSelected;

  @override
  State<ProgressPathScreen> createState() => _ProgressPathScreenState();
}

class _ProgressPathScreenState extends State<ProgressPathScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late final List<GlobalKey> _cardKeys;
  bool _allUnlocked = false;

  @override
  void didUpdateWidget(covariant ProgressPathScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStageIndex != widget.currentStageIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentStage());
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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Start animation after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
  _controller.forward();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentStage();
        });
      }
    });
    // Load unlock flag
    () async {
      final unlocked = await const GamePersistence().isAllScreensUnlocked();
      if (mounted) setState(() => _allUnlocked = unlocked);
    }();
  }

  void _scrollToCurrentStage() {
    if (!mounted || _cardKeys.isEmpty) return;
    final index = widget.currentStageIndex.clamp(0, _cardKeys.length - 1);
    final context = _cardKeys[index].currentContext;
    if (context == null) {
      // Try again on next frame if layout not ready
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentStage());
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.35,
    );
  }

  void _dismissScreen({int? selectedStageIndex, bool resumeGameplay = true}) async {
    if (_controller.isAnimating) return;
    await _controller.reverse();
    if (mounted) {
      // If a stage was selected, trigger the callback
      if (selectedStageIndex != null && widget.onScreenSelected != null) {
        widget.onScreenSelected!(selectedStageIndex);
      }
      // Always call onComplete to dismiss the screen
      widget.onComplete(resumeGameplay);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<FeedbackSettings>();
    final isDark = settings.theme == AppTheme.kashyap;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _GlassProgressAppBar(
        title: 'BollyWord Multiplex',
        onClose: () => _dismissScreen(resumeGameplay: false),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Image.asset(
                isDark ? 'assets/Options_Dark.png' : 'assets/Options_Light.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  
                  // Scrollable screens list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      itemCount: widget.allStages.length + 1, // +1 for "coming soon" message
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenCard(int index) {
    final settings = context.watch<FeedbackSettings>();
    final isDark = settings.theme == AppTheme.kashyap;
    final stage = widget.allStages[index];
    final isPast = index < widget.currentStageIndex;
    final isCurrent = index == widget.currentStageIndex;
    final isFuture = index > widget.currentStageIndex;
  final isClickable = isPast || isCurrent || (_allUnlocked && isFuture); // Can click completed or current screen (or all if unlocked)
    
    // Calculate completed scenes for this stage
    int completedScenes = 0;
    if (isPast) {
      completedScenes = 3; // All scenes completed
    } else if (isCurrent) {
      completedScenes = widget.currentSceneIndex;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
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
      child: GestureDetector(
        key: _cardKeys[index],
        onTap: isClickable
            ? () {
                // Show confirmation dialog for completed screens
                if (isPast) {
                  _showReplayConfirmation(index);
                } else if (_allUnlocked && isFuture) {
                  // Jump straight to the unlocked future screen
                  _dismissScreen(selectedStageIndex: index, resumeGameplay: true);
                } else {
                  // Current screen - just dismiss and continue
                  _dismissScreen(resumeGameplay: true);
                }
              }
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 32),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(20),
            backgroundGradient: LinearGradient(
              colors: isDark
                  ? [Colors.white.withAlpha(26), Colors.white.withAlpha(13)]
                  : [Colors.white.withAlpha(97), Colors.white.withAlpha(46)],
            ),
            borderColor: Colors.white.withAlpha(isDark ? 51 : 71),
            elevationColor: Colors.black.withAlpha(isDark ? 90 : 46),
            child: Padding(
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
                      // Screen number or checkmark
                      if (isPast)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(230),
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
                                ? Theme.of(context).colorScheme.primary.withAlpha(230)
                                : Colors.grey.withAlpha(179),
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
                          'Screen ${index + 1}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w700,
                            color: isFuture
                                ? Colors.grey
                                : isCurrent
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Theme.of(context).colorScheme.onSurface,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Now showing: ${stage.themeName} Scene ${isPast ? 3 : isCurrent ? widget.currentSceneIndex + 1 : 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isCurrent
                                ? Theme.of(context).colorScheme.onSurface.withAlpha(204)
                                : Theme.of(context).colorScheme.onSurface.withAlpha(179),
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
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.green)
                                      : Theme.of(context).colorScheme.outline.withAlpha(77),
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
                    (_allUnlocked
                        ? const Icon(
                            Icons.lock_open,
                            color: Colors.green,
                            size: 28,
                          )
                        : const Icon(
                            Icons.lock_outline,
                            color: Colors.grey,
                            size: 28,
                          ))
                  else if (isPast)
                    Icon(
                      Icons.replay,
                      color: Theme.of(context).colorScheme.primary.withAlpha(179),
                      size: 28,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
      _dismissScreen(selectedStageIndex: stageIndex, resumeGameplay: true);
    }
  }

  Widget _buildComingSoonCard() {
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withAlpha(128),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withAlpha(77),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.movie_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(102),
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
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'New challenges and themes on the way!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassProgressAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _GlassProgressAppBar({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  static const double preferredHeight = 72;

  @override
  Size get preferredSize => const Size.fromHeight(preferredHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = theme.colorScheme.onSurface.withAlpha(217);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: _GlassSurface(
          borderRadius: BorderRadius.circular(24),
          backgroundGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.white.withAlpha(31),
                    Colors.white.withAlpha(13),
                  ]
                : [
                    Colors.white.withAlpha(115),
                    Colors.white.withAlpha(51),
                  ],
          ),
          borderColor: Colors.white.withAlpha(isDark ? 56 : 90),
          elevationColor: Colors.black.withAlpha(isDark ? 82 : 41),
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              height: preferredHeight,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: iconColor,
                    onPressed: onClose,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: iconColor,
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
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    this.borderRadius,
    this.backgroundGradient,
    this.borderColor,
    this.elevationColor,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final Gradient? backgroundGradient;
  final Color? borderColor;
  final Color? elevationColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: elevationColor != null
            ? [
                BoxShadow(
                  color: elevationColor!,
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: backgroundGradient,
              border: borderColor != null
                  ? Border.all(color: borderColor!, width: 1.5)
                  : null,
              borderRadius: borderRadius,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
