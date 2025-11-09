import 'dart:async';
import 'package:flutter/material.dart';
import '../models/stage_scene.dart';

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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _showDetails = false;
  late final List<GlobalKey> _cardKeys;

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
        setState(() => _showDetails = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentStage();
        });
      }
    });
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pathImage = isDark
        ? 'assets/BWGrid Path_Dark.png'
        : 'assets/BWGrid Path_Light.png';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(pathImage),
            fit: BoxFit.cover,
            opacity: 0.15,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'BollyWord Multiplex',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                
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
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
      ),
    );
  }

  Widget _buildScreenCard(int index) {
    final stage = widget.allStages[index];
    final isPast = index < widget.currentStageIndex;
    final isCurrent = index == widget.currentStageIndex;
    final isFuture = index > widget.currentStageIndex;
    final isClickable = isPast || isCurrent; // Can click completed or current screen
    
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
                } else {
                  // Current screen - just dismiss and continue
                  _dismissScreen();
                }
              }
      : null,
    child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isCurrent
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCurrent
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: isCurrent ? 3 : 1.5,
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
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
                      color: Colors.green.withOpacity(0.9),
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
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.9)
                          : Colors.grey.withOpacity(0.7),
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
                      fontWeight: FontWeight.w700,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stage.themeName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8)
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                size: 28,
              )
            else if (isPast)
              Icon(
                Icons.replay,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                size: 28,
              ),
          ],
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
      _dismissScreen(selectedStageIndex: stageIndex);
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
          color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
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
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'New challenges and themes on the way!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
