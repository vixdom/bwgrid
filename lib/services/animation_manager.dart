import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Optimized animation manager that reduces overhead and improves performance
/// by efficiently managing animation controllers and reducing unnecessary computations.
class AnimationManager {
  static final AnimationManager _instance = AnimationManager._internal();
  factory AnimationManager() => _instance;
  AnimationManager._internal();

  // Pool of reusable animation controllers
  final Map<String, AnimationController> _controllerPool = {};
  
  // Active animations being managed
  final Set<AnimationController> _activeControllers = {};
  
  // Cached animation curves for reuse
  final Map<String, Curve> _curveCache = {
    'easeIn': Curves.easeIn,
    'easeOut': Curves.easeOut,
    'easeInOut': Curves.easeInOut,
    'elasticOut': Curves.elasticOut,
    'bounceOut': Curves.bounceOut,
    'fastOutSlowIn': Curves.fastOutSlowIn,
  };

  // Cached tween animations for common patterns
  final Map<String, Tween<double>> _tweenCache = {};
  
  bool _isDisposed = false;

  /// Get an optimized animation controller with caching
  AnimationController getController({
    required Duration duration,
    required TickerProvider vsync,
    String? id,
    Duration? reverseDuration,
  }) {
    if (_isDisposed) {
      throw StateError('AnimationManager has been disposed');
    }

    final controllerId = id ?? '${duration.inMilliseconds}_${DateTime.now().microsecondsSinceEpoch}';
    
    // Check if we can reuse an existing controller
    if (_controllerPool.containsKey(controllerId)) {
      final controller = _controllerPool[controllerId]!;
      _activeControllers.add(controller);
      return controller;
    }

    // Create new optimized controller
    final controller = AnimationController(
      duration: duration,
      reverseDuration: reverseDuration,
      vsync: vsync,
    );

    _activeControllers.add(controller);
    
    // Cache for potential reuse
    if (id != null) {
      _controllerPool[controllerId] = controller;
    }

    return controller;
  }

  /// Get a cached curve for optimal performance
  Curve getCurve(String curveName) {
    return _curveCache[curveName] ?? Curves.linear;
  }

  /// Get an optimized tween with caching
  Tween<double> getTween(double begin, double end, {String? id}) {
    final tweenId = id ?? '${begin}_$end';
    
    if (_tweenCache.containsKey(tweenId)) {
      return _tweenCache[tweenId]!;
    }

    final tween = Tween<double>(begin: begin, end: end);
    _tweenCache[tweenId] = tween;
    return tween;
  }

  /// Create an optimized animation with caching
  Animation<double> createAnimation({
    required AnimationController controller,
    required double begin,
    required double end,
    String curveName = 'linear',
    Interval? interval,
    String? id,
  }) {
    final tween = getTween(begin, end, id: id);
    final curve = getCurve(curveName);
    
    if (interval != null) {
      return tween.animate(CurvedAnimation(
        parent: controller,
        curve: Interval(interval.begin, interval.end, curve: curve),
      ));
    } else {
      return tween.animate(CurvedAnimation(
        parent: controller,
        curve: curve,
      ));
    }
  }

  /// Release a controller back to the pool
  void releaseController(AnimationController controller, {String? id}) {
    if (_isDisposed) return;

    _activeControllers.remove(controller);
    
    // Reset controller state for reuse
    try {
      controller.reset();
    } catch (e) {
      debugPrint('[AnimationManager] Error resetting controller: $e');
    }
    
    // Keep in pool for reuse if it has an ID
    if (id != null && !_controllerPool.containsKey(id)) {
      _controllerPool[id] = controller;
    }
  }

  /// Clean up unused controllers to prevent memory leaks
  void cleanupUnusedControllers() {
    if (_isDisposed) return;

    final controllersToRemove = <String>[];
    
    for (final entry in _controllerPool.entries) {
      final controller = entry.value;
      if (!_activeControllers.contains(controller)) {
        try {
          controller.dispose();
          controllersToRemove.add(entry.key);
        } catch (e) {
          debugPrint('[AnimationManager] Error disposing controller: $e');
        }
      }
    }
    
    for (final id in controllersToRemove) {
      _controllerPool.remove(id);
    }
    
    debugPrint('[AnimationManager] Cleaned up ${controllersToRemove.length} unused controllers');
  }

  /// Get current animation statistics
  Map<String, dynamic> getStats() {
    return {
      'activeControllers': _activeControllers.length,
      'pooledControllers': _controllerPool.length,
      'cachedCurves': _curveCache.length,
      'cachedTweens': _tweenCache.length,
      'isDisposed': _isDisposed,
    };
  }

  /// Dispose all animations and clean up resources
  void dispose() {
    if (_isDisposed) return;
    
    _isDisposed = true;
    debugPrint('[AnimationManager] Disposing all animation controllers...');

    // Dispose all controllers
    final allControllers = [
      ..._activeControllers,
      ..._controllerPool.values,
    ];

    final disposeFutures = allControllers.map((controller) async {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('[AnimationManager] Error disposing controller: $e');
      }
    });

    Future.wait(disposeFutures, eagerError: false);

    _activeControllers.clear();
    _controllerPool.clear();
    _tweenCache.clear();

    debugPrint('[AnimationManager] Disposed ${allControllers.length} animation controllers');
  }
}

/// Optimized confetti system that reduces animation overhead
class OptimizedConfetti {
  static const int _maxParticles = 20; // Reduced from 28 for better performance
  /// Create optimized confetti particles with reduced computational overhead
  static List<ConfettiParticle> createParticles(Size screenSize) {
    final random = math.Random();
    final center = Offset(screenSize.width / 2, screenSize.height / 2);
    
    return List.generate(_maxParticles, (i) {
      // Pre-compute values to avoid calculations during animation
      final angle = (i / _maxParticles) * 2 * math.pi + random.nextDouble() * 0.5;
      final distance = 100 + random.nextDouble() * 150;
      final velocity = Offset(
        math.cos(angle) * distance,
        math.sin(angle) * distance,
      );
      
      return ConfettiParticle(
        startPosition: center,
        velocity: velocity,
        color: _getOptimizedColor(i),
        size: 3.0 + random.nextDouble() * 4.0,
        rotationSpeed: random.nextDouble() * 4 - 2,
      );
    });
  }

  /// Pre-defined colors for better performance
  static Color _getOptimizedColor(int index) {
    const colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
    ];
    return colors[index % colors.length];
  }
}

/// Optimized confetti particle with pre-computed values
class ConfettiParticle {
  final Offset startPosition;
  final Offset velocity;
  final Color color;
  final double size;
  final double rotationSpeed;
  
  ConfettiParticle({
    required this.startPosition,
    required this.velocity,
    required this.color,
    required this.size,
    required this.rotationSpeed,
  });

  /// Calculate position at given animation progress (0.0 to 1.0)
  Offset getPosition(double progress) {
    final gravity = 200 * progress * progress; // Simplified gravity
    return Offset(
      startPosition.dx + velocity.dx * progress,
      startPosition.dy + velocity.dy * progress + gravity,
    );
  }

  /// Calculate rotation at given animation progress
  double getRotation(double progress) {
    return rotationSpeed * progress * 360;
  }
}

/// Optimized animated widget builder that reduces rebuild overhead
class OptimizedAnimatedBuilder extends StatelessWidget {
  const OptimizedAnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  final Animation<double> animation;
  final Widget Function(BuildContext context, double value, Widget? child) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => builder(context, animation.value, child),
    );
  }
}