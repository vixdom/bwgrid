import 'dart:async';
import 'package:flutter/material.dart';
import '../models/stage_scene.dart';

/// Displays the player's progress through all screens/stages
/// Shows completed, current, and upcoming screens with animated transitions
class ProgressPathScreen extends StatefulWidget {
  const ProgressPathScreen({
    super.key,
    required this.allStages,
    required this.currentStageIndex,
    required this.currentSceneIndex,
    required this.onComplete,
  });

  final List<StageDefinition> allStages;
  final int currentStageIndex;
  final int currentSceneIndex;
  final VoidCallback onComplete;

  @override
  State<ProgressPathScreen> createState() => _ProgressPathScreenState();
}

class _ProgressPathScreenState extends State<ProgressPathScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
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
      }
    });
  }

  void _dismissScreen() async {
    if (_controller.isAnimating) return;
    await _controller.reverse();
    if (mounted) {
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
                  child: Text(
                    'Your Journey',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                
                // Scrollable screens list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemCount: widget.allStages.length,
                    itemBuilder: (context, index) {
                      return _buildScreenCard(index);
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
            
            // Lock icon for future screens
            if (isFuture)
              Icon(
                Icons.lock_outline,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                size: 28,
              ),
          ],
        ),
      ),
    );
  }


}
