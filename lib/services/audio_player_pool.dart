import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Optimized audio player pool for efficient memory management and performance.
/// Reuses AudioPlayer instances to reduce memory allocation and initialization overhead.
class AudioPlayerPool {
  static final AudioPlayerPool _instance = AudioPlayerPool._internal();
  factory AudioPlayerPool() => _instance;
  AudioPlayerPool._internal();

  // Pool of available AudioPlayers for reuse
  final Queue<AudioPlayer> _availablePlayers = Queue<AudioPlayer>();
  
  // Currently active (in-use) players
  final Set<AudioPlayer> _activePlayers = <AudioPlayer>{};
  
  // Map from asset path to prepared players for instant playback
  final Map<String, AudioPlayer> _preparedPlayers = <String, AudioPlayer>{};
  
  // Maximum number of players to keep in pool
  static const int _maxPoolSize = 8;
  
  // Maximum number of prepared players (for frequently used sounds)
  static const int _maxPreparedPlayers = 5;
  
  bool _isDisposed = false;

  /// Get an AudioPlayer from the pool, creating a new one if necessary
  Future<AudioPlayer> acquire() async {
    if (_isDisposed) {
      throw StateError('AudioPlayerPool has been disposed');
    }

    AudioPlayer player;
    
    if (_availablePlayers.isNotEmpty) {
      player = _availablePlayers.removeFirst();
      debugPrint('[AudioPlayerPool] Reused existing player from pool (${_availablePlayers.length} remaining)');
    } else {
      player = AudioPlayer();
      debugPrint('[AudioPlayerPool] Created new AudioPlayer (total active: ${_activePlayers.length + 1})');
    }
    
    _activePlayers.add(player);
    return player;
  }

  /// Return an AudioPlayer to the pool for reuse
  Future<void> release(AudioPlayer player) async {
    if (_isDisposed || !_activePlayers.contains(player)) {
      return;
    }

    _activePlayers.remove(player);

    try {
      // Stop playback and reset player state
      await player.stop();
      await player.seek(Duration.zero);
      
      // Return to pool if we haven't exceeded the limit
      if (_availablePlayers.length < _maxPoolSize) {
        _availablePlayers.add(player);
        debugPrint('[AudioPlayerPool] Returned player to pool (${_availablePlayers.length} available)');
      } else {
        // Dispose excess players to prevent memory bloat
        await player.dispose();
        debugPrint('[AudioPlayerPool] Disposed excess AudioPlayer');
      }
    } catch (e) {
      debugPrint('[AudioPlayerPool] Error releasing player: $e');
      // Dispose problematic players
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  /// Prepare an AudioPlayer with a specific asset for instant playback
  Future<AudioPlayer?> preparePlayer(String assetPath) async {
    if (_isDisposed) return null;

    // Check if already prepared
    if (_preparedPlayers.containsKey(assetPath)) {
      return _preparedPlayers[assetPath];
    }

    // Limit number of prepared players
    if (_preparedPlayers.length >= _maxPreparedPlayers) {
      debugPrint('[AudioPlayerPool] Max prepared players reached, not preparing $assetPath');
      return null;
    }

    try {
      final player = await acquire();
      await player.setAsset(assetPath);
      
      // Release from active pool since it's now a prepared player
      _activePlayers.remove(player);
      _preparedPlayers[assetPath] = player;
      
      debugPrint('[AudioPlayerPool] Prepared player for $assetPath (${_preparedPlayers.length} prepared)');
      return player;
    } catch (e) {
      debugPrint('[AudioPlayerPool] Failed to prepare player for $assetPath: $e');
      return null;
    }
  }

  /// Get a prepared player for instant playback (if available)
  AudioPlayer? getPreparedPlayer(String assetPath) {
    return _preparedPlayers[assetPath];
  }

  /// Play sound using the optimal strategy (prepared player or pool)
  Future<void> playOptimized(String assetPath) async {
    if (_isDisposed) return;

    // Try prepared player first for instant playback
    final preparedPlayer = _preparedPlayers[assetPath];
    if (preparedPlayer != null) {
      try {
        await preparedPlayer.seek(Duration.zero);
        await preparedPlayer.play();
        debugPrint('[AudioPlayerPool] Played using prepared player: $assetPath');
        return;
      } catch (e) {
        debugPrint('[AudioPlayerPool] Error with prepared player, falling back: $e');
        // Remove failed prepared player
        _preparedPlayers.remove(assetPath);
        try {
          await preparedPlayer.dispose();
        } catch (_) {}
      }
    }

    // Fall back to pool-based playback
    AudioPlayer? player;
    try {
      player = await acquire();
      await player.setAsset(assetPath);
      await player.play();
      debugPrint('[AudioPlayerPool] Played using pool player: $assetPath');
      
      // Auto-release after playback completes
      player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          unawaited(release(player!));
        }
      });
    } catch (e) {
      debugPrint('[AudioPlayerPool] Error playing $assetPath: $e');
      if (player != null) {
        unawaited(release(player));
      }
    }
  }

  /// Get current pool statistics for debugging
  Map<String, dynamic> getStats() {
    return {
      'availablePlayers': _availablePlayers.length,
      'activePlayers': _activePlayers.length,
      'preparedPlayers': _preparedPlayers.length,
      'preparedAssets': _preparedPlayers.keys.toList(),
      'totalPlayers': _availablePlayers.length + _activePlayers.length + _preparedPlayers.length,
      'isDisposed': _isDisposed,
    };
  }

  /// Clean up old prepared players that haven't been used recently
  Future<void> cleanupPreparedPlayers() async {
    if (_isDisposed) return;

    // Simple cleanup: remove all prepared players to free memory
    // In a more sophisticated version, we could track usage timestamps
    final playersToDispose = List<AudioPlayer>.from(_preparedPlayers.values);
    _preparedPlayers.clear();
    
    for (final player in playersToDispose) {
      try {
        await player.dispose();
      } catch (e) {
        debugPrint('[AudioPlayerPool] Error disposing prepared player: $e');
      }
    }
    
    debugPrint('[AudioPlayerPool] Cleaned up ${playersToDispose.length} prepared players');
  }

  /// Dispose all players and clean up resources
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _isDisposed = true;
    debugPrint('[AudioPlayerPool] Disposing all audio players...');

    // Dispose all players
    final allPlayers = [
      ..._availablePlayers,
      ..._activePlayers,
      ..._preparedPlayers.values,
    ];

    final disposeFutures = allPlayers.map((player) async {
      try {
        await player.dispose();
      } catch (e) {
        debugPrint('[AudioPlayerPool] Error disposing player: $e');
      }
    });

    await Future.wait(disposeFutures, eagerError: false);

    _availablePlayers.clear();
    _activePlayers.clear();
    _preparedPlayers.clear();

    debugPrint('[AudioPlayerPool] Disposed ${allPlayers.length} audio players');
  }
}