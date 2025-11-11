import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Asset preloading service that efficiently caches images and prepares audio files
/// for immediate use during gameplay to eliminate loading delays.
class AssetPreloader {
  static final AssetPreloader _instance = AssetPreloader._internal();
  factory AssetPreloader() => _instance;
  AssetPreloader._internal();

  bool _isPreloading = false;
  bool _preloadingCompleted = false;
  final Set<String> _preloadedImages = {};
  final Map<String, AudioPlayer> _preloadedAudio = {};
  final Completer<void> _preloadCompleter = Completer<void>();

  /// Returns true if preloading is currently in progress
  bool get isPreloading => _isPreloading;

  /// Returns true if all assets have been successfully preloaded
  bool get isCompleted => _preloadingCompleted;

  /// Returns a future that completes when all preloading is finished
  Future<void> get preloadingCompleted => _preloadCompleter.future;

  /// Critical images used throughout the app
  static const List<String> _criticalImages = [
    'assets/BollyWord Splash Screen.png',
    'assets/BollyWord welcome screen gold.png',
    'assets/BollyWord welcome screen.png',
    'assets/images/screen_cropped.png',
    'assets/Options_Light.png',
    'assets/Options_Dark.png',
  ];

  /// Critical audio files used during gameplay
  static const List<String> _criticalAudio = [
    'assets/audio/select.wav',
    'assets/audio/word_found.wav',
    'assets/audio/invalid.wav',
    'assets/audio/fireworks.wav',
    'assets/audio/clue.wav',
    'assets/audio/tick_soft.wav',
    'assets/audio/clap board.mp3',
  ];

  /// Preload all critical assets for the app
  /// Should be called early in the app lifecycle (during boot/splash)
  Future<void> preloadCriticalAssets(BuildContext context) async {
    if (_isPreloading || _preloadingCompleted) {
      return _preloadCompleter.future;
    }

    _isPreloading = true;
    debugPrint('[AssetPreloader] Starting critical asset preloading...');

    try {
      // Preload images and audio in parallel for maximum efficiency
      await Future.wait([
        _preloadImages(context),
        _preloadAudio(),
      ], eagerError: false); // Continue even if some assets fail

      _preloadingCompleted = true;
      _isPreloading = false;
      _preloadCompleter.complete();

      debugPrint(
        '[AssetPreloader] Critical asset preloading completed successfully',
      );
      debugPrint(
        '[AssetPreloader] Preloaded ${_preloadedImages.length} images and ${_preloadedAudio.length} audio files',
      );
    } catch (e) {
      debugPrint('[AssetPreloader] Error during preloading: $e');
      _isPreloading = false;
      _preloadCompleter.complete(); // Complete anyway to avoid blocking the app
    }
  }

  /// Preload additional assets in the background after critical assets are loaded
  Future<void> preloadNonCriticalAssets(BuildContext context) async {
    if (!_preloadingCompleted) {
      await preloadingCompleted;
    }

    debugPrint('[AssetPreloader] Starting non-critical asset preloading...');

    try {
      // Preload fallback audio formats
      final nonCriticalAudio = [
        'assets/audio/select.mp3',
        'assets/audio/word_found.mp3',
        'assets/audio/invalid.mp3',
        'assets/audio/fireworks.mp3',
        'assets/audio/clue.mp3',
        'assets/audio/tick_soft.mp3',
        'assets/audio/clap board.mp3',
        'assets/music/Midnight Monsoon.mp3',
        'assets/music/Midnight Monsoon 2.mp3',
        'assets/music/Wordplay Raga.mp3',
        'assets/music/Wordplay Raga 2.mp3',
      ];

      await _preloadAudioFiles(nonCriticalAudio);
      debugPrint('[AssetPreloader] Non-critical asset preloading completed');
    } catch (e) {
      debugPrint('[AssetPreloader] Error during non-critical preloading: $e');
    }
  }

  /// Check if a specific image has been preloaded
  bool isImagePreloaded(String assetPath) =>
      _preloadedImages.contains(assetPath);

  /// Check if a specific audio file has been preloaded
  bool isAudioPreloaded(String assetPath) =>
      _preloadedAudio.containsKey(assetPath);

  /// Get a preloaded audio player (returns null if not preloaded)
  AudioPlayer? getPreloadedAudioPlayer(String assetPath) =>
      _preloadedAudio[assetPath];

  /// Preload all critical images
  Future<void> _preloadImages(BuildContext context) async {
    final futures = _criticalImages.map((imagePath) async {
      try {
        await precacheImage(AssetImage(imagePath), context);
        _preloadedImages.add(imagePath);
        debugPrint('[AssetPreloader] Cached image: $imagePath');
      } catch (e) {
        debugPrint('[AssetPreloader] Failed to cache image $imagePath: $e');
      }
    });

    await Future.wait(futures, eagerError: false);
  }

  /// Preload all critical audio files
  Future<void> _preloadAudio() async {
    await _preloadAudioFiles(_criticalAudio);
  }

  /// Preload a list of audio files
  Future<void> _preloadAudioFiles(List<String> audioFiles) async {
    final futures = audioFiles.map((audioPath) async {
      try {
        final player = AudioPlayer();
        await player.setAsset(audioPath);
        _preloadedAudio[audioPath] = player;
        debugPrint('[AssetPreloader] Preloaded audio: $audioPath');
      } catch (e) {
        debugPrint('[AssetPreloader] Failed to preload audio $audioPath: $e');
      }
    });

    await Future.wait(futures, eagerError: false);
  }

  /// Dispose of all preloaded audio players to free memory
  Future<void> dispose() async {
    debugPrint('[AssetPreloader] Disposing preloaded audio players...');

    final futures = _preloadedAudio.values.map((player) async {
      try {
        await player.dispose();
      } catch (e) {
        debugPrint('[AssetPreloader] Error disposing audio player: $e');
      }
    });

    await Future.wait(futures, eagerError: false);
    _preloadedAudio.clear();
  }

  /// Get memory usage statistics for debugging
  Map<String, dynamic> getStats() {
    return {
      'isPreloading': _isPreloading,
      'isCompleted': _preloadingCompleted,
      'preloadedImages': _preloadedImages.length,
      'preloadedAudio': _preloadedAudio.length,
      'imageList': _preloadedImages.toList(),
      'audioList': _preloadedAudio.keys.toList(),
    };
  }
}
