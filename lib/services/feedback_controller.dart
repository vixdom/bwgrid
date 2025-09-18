import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart';

import '../models/feedback_settings.dart';
import 'asset_preloader.dart';

/// FeedbackController manages short SFX and haptics with debounce and settings.
/// Provide it via Provider and dispose on app shutdown.
class FeedbackController with ChangeNotifier {
  final FeedbackSettings settings;
  bool _isInitializing = false;

  final AudioPlayer _tick = AudioPlayer();
  final AudioPlayer _found = AudioPlayer();
  final AudioPlayer _invalid = AudioPlayer();
  final AudioPlayer _fireworks = AudioPlayer();
  final AudioPlayer _clue = AudioPlayer();
  String? _tickAssetName;
  String? _foundAssetName;
  String? _invalidAssetName;
  String? _fireworksAssetName;
  String? _clueAssetName;
  int? _tickMs;
  int? _foundMs;
  int? _invalidMs;
  int? _fireworksMs;
  int? _clueMs;

  DateTime _lastTickAt = DateTime.fromMillisecondsSinceEpoch(0);
  Duration tickThrottle = const Duration(milliseconds: 50); // 40-60ms
  bool _audioAvailable = true; // disabled on web or if init fails fatally
  bool _tickReady = false;
  bool _foundReady = false;
  bool _invalidReady = false;
  bool _fireworksReady = false;
  bool _clueReady = false;
  String? _tickError;
  String? _foundError;
  String? _invalidError;
  String? _fireworksError;
  String? _clueError;
  static const MethodChannel _hapticChannel = MethodChannel('bwgrid/haptics');
  static const MethodChannel _audioChannel = MethodChannel('bwgrid/audio');

  FeedbackController(this.settings);

  /// Optimized audio loading that uses preloaded assets when available
  Future<Duration?> _loadAudioOptimized(AudioPlayer player, String wavFile, String mp3File) async {
    final assetPreloader = AssetPreloader();
    
    // Try to use preloaded assets first for instant loading
    final wavPath = _assetPath(wavFile);
    final mp3Path = _assetPath(mp3File);
    
    AudioPlayer? preloadedPlayer = assetPreloader.getPreloadedAudioPlayer(wavPath);
    if (preloadedPlayer != null) {
      debugPrint('Using preloaded WAV audio: $wavPath');
      // Copy the preloaded player's state to our player
      try {
        final duration = await player.setAsset(wavPath);
        return duration;
      } catch (e) {
        debugPrint('Failed to use preloaded WAV, falling back: $e');
      }
    }
    
    preloadedPlayer = assetPreloader.getPreloadedAudioPlayer(mp3Path);
    if (preloadedPlayer != null) {
      debugPrint('Using preloaded MP3 audio: $mp3Path');
      try {
        final duration = await player.setAsset(mp3Path);
        return duration;
      } catch (e) {
        debugPrint('Failed to use preloaded MP3, falling back: $e');
      }
    }
    
    // Fall back to normal loading if no preloaded assets available
    try {
      final duration = await player.setAsset(wavPath);
      debugPrint('Loaded WAV audio normally: $wavPath');
      return duration;
    } catch (e) {
      debugPrint('Failed to load WAV, trying MP3: $e');
      final duration = await player.setAsset(mp3Path);
      debugPrint('Loaded MP3 audio normally: $mp3Path');
      return duration;
    }
  }
  
  // Read-only exposure for UI/debug
  String get tickAssetName => _tickAssetName ?? 'unknown';
  String get foundAssetName => _foundAssetName ?? 'unknown';
  String get invalidAssetName => _invalidAssetName ?? 'unknown';
  String get fireworksAssetName => _fireworksAssetName ?? 'unknown';
  String get clueAssetName => _clueAssetName ?? 'unknown';
  int? get tickDurationMs => _tickMs;
  int? get foundDurationMs => _foundMs;
  int? get invalidDurationMs => _invalidMs;
  int? get fireworksDurationMs => _fireworksMs;
  int? get clueDurationMs => _clueMs;
  bool get tickReady => _tickReady;
  bool get foundReady => _foundReady;
  bool get invalidReady => _invalidReady;
  bool get fireworksReady => _fireworksReady;
  bool get clueReady => _clueReady;
  String? get tickError => _tickError;
  String? get foundError => _foundError;
  String? get invalidError => _invalidError;
  String? get fireworksError => _fireworksError;
  String? get clueError => _clueError;

  Future<void> _initializeTickSound() async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('Initializing tick sound... (attempt $attempt/$maxRetries)');
        
        // Use optimized loading with preloaded assets
        final d = await _loadAudioOptimized(_tick, 'select.wav', 'select.mp3');
        
        _tickReady = true;
        _tickAssetName = d != null ? 'select (optimized)' : 'select';
        _tickMs = d?.inMilliseconds;
        _tick.setVolume(settings.volume);
        _tickError = null;
        debugPrint('Tick sound initialized successfully (duration: ${_tickMs ?? -1}ms)');
        notifyListeners();
        return; // Success, exit retry loop
      } catch (e) {
        final msg = e is PlatformException
          ? 'code=${e.code}, message=${e.message}, details=${e.details}'
          : e.toString();
        debugPrint('Error initializing tick sound (attempt $attempt/$maxRetries): $msg');
        
        if (attempt == maxRetries) {
          _tickReady = false;
          _tickError = msg;
          notifyListeners();
        } else {
          // Wait before retry
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
  }

  Future<void> _initializeFoundSound() async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('Initializing word found sound... (attempt $attempt/$maxRetries)');
        
        // Use optimized loading with preloaded assets
        final d = await _loadAudioOptimized(_found, 'word_found.wav', 'word_found.mp3');
        
        _foundReady = true;
        _foundAssetName = d != null ? 'word_found (optimized)' : 'word_found';
        _foundMs = d?.inMilliseconds;
        _found.setVolume(settings.volume);
        _foundError = null;
        debugPrint('Word found sound initialized successfully (duration: ${_foundMs ?? -1}ms)');
        notifyListeners();
        return;
      } catch (e) {
        final msg = e is PlatformException
          ? 'code=${e.code}, message=${e.message}, details=${e.details}'
          : e.toString();
        debugPrint('Error initializing word found sound (attempt $attempt/$maxRetries): $msg');
        
        if (attempt == maxRetries) {
          _foundReady = false;
          _foundError = msg;
          notifyListeners();
        } else {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
  }

  Future<void> _initializeInvalidSound() async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('Initializing invalid sound... (attempt $attempt/$maxRetries)');
        
        // Use optimized loading with preloaded assets
        final d = await _loadAudioOptimized(_invalid, 'invalid.wav', 'invalid.mp3');
        
        _invalidReady = true;
        _invalidAssetName = d != null ? 'invalid (optimized)' : 'invalid';
        _invalidMs = d?.inMilliseconds;
        _invalid.setVolume(settings.volume);
        _invalidError = null;
        debugPrint('Invalid sound initialized successfully (duration: ${_invalidMs ?? -1}ms)');
        notifyListeners();
        return;
      } catch (e) {
        final msg = e is PlatformException
          ? 'code=${e.code}, message=${e.message}, details=${e.details}'
          : e.toString();
        debugPrint('Error initializing invalid sound (attempt $attempt/$maxRetries): $msg');
        
        if (attempt == maxRetries) {
          _invalidReady = false;
          _invalidError = msg;
          notifyListeners();
        } else {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
  }

  Future<void> _initializeFireworksSound() async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('Initializing fireworks sound... (attempt $attempt/$maxRetries)');
        
        // Use optimized loading with preloaded assets
        final d = await _loadAudioOptimized(_fireworks, 'fireworks.wav', 'fireworks.mp3');
        
        _fireworksReady = true;
        _fireworksAssetName = d != null ? 'fireworks (optimized)' : 'fireworks';
        _fireworksMs = d?.inMilliseconds;
        _fireworks.setVolume(settings.volume);
        _fireworksError = null;
        debugPrint('Fireworks sound initialized successfully (duration: ${_fireworksMs ?? -1}ms)');
        notifyListeners();
        return;
      } catch (e) {
        final msg = e is PlatformException
          ? 'code=${e.code}, message=${e.message}, details=${e.details}'
          : e.toString();
        debugPrint('Error initializing fireworks sound (attempt $attempt/$maxRetries): $msg');
        
        if (attempt == maxRetries) {
          _fireworksReady = false;
          _fireworksError = msg;
          notifyListeners();
        } else {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
  }

  Future<void> _initializeClueSound() async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('Initializing clue sound... (attempt $attempt/$maxRetries)');
        
        // Use optimized loading with preloaded assets
        final d = await _loadAudioOptimized(_clue, 'clue.wav', 'clue.mp3');
        
        _clueReady = true;
        _clueAssetName = d != null ? 'clue (optimized)' : 'clue';
        _clueMs = d?.inMilliseconds;
        _clue.setVolume(settings.volume);
        _clueError = null;
        debugPrint('Clue sound initialized successfully (duration: ${_clueMs ?? -1}ms)');
        notifyListeners();
        return;
      } catch (e) {
        final msg = e is PlatformException
          ? 'code=${e.code}, message=${e.message}, details=${e.details}'
          : e.toString();
        debugPrint('Error initializing clue sound (attempt $attempt/$maxRetries): $msg');
        
        if (attempt == maxRetries) {
          _clueReady = false;
          _clueError = msg;
          notifyListeners();
        } else {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
  }

  Future<void> init() async {
    debugPrint('Initializing FeedbackController...');
    // Disable audio on web during development when assets may be placeholders
    if (kIsWeb) {
      _audioAvailable = false;
      debugPrint('FeedbackController: audio disabled on Web build (skip preload)');
      return;
    }
    
    // Initialize audio in background to avoid blocking UI
    _initializeAudioInBackground();
  }

  Future<void> _initializeAudioInBackground() async {
    if (_isInitializing) return;
    _isInitializing = true;
    
    try {
      debugPrint('Configuring audio session in background...');
      await _configureSession();
      
      // Initialize sounds in the background
      debugPrint('Starting background sound initialization...');
      
      // Don't block the UI - initialize sounds in background
      Future.microtask(() async {
        try {
          await _initializeSounds();
          _audioAvailable = true;
          debugPrint('Sound effects initialized successfully');
        } catch (e) {
          _audioAvailable = false;
          debugPrint('Error initializing sounds (non-fatal): $e');
        } finally {
          _isInitializing = false;
          notifyListeners();
        }
      });
      
    } catch (e) {
      _audioAvailable = false;
      _isInitializing = false;
      debugPrint('Error initializing audio session (non-fatal): $e');
      notifyListeners();
    }
  }

  Future<void> _initializeSounds() async {
    try {
      // Initialize sounds sequentially to avoid overwhelming the system
      debugPrint('Initializing tick sound...');
      await _initializeTickSound();
      
      debugPrint('Initializing found sound...');
      await _initializeFoundSound();
      
      debugPrint('Initializing invalid sound...');
      await _initializeInvalidSound();
      
      debugPrint('Initializing fireworks sound...');
      await _initializeFireworksSound();
      
      debugPrint('Initializing clue sound...');
      await _initializeClueSound();
      
      debugPrint('All sounds initialized successfully');
    } catch (e) {
      debugPrint('Error initializing sounds: $e');
      rethrow;
    }
  }

  String _assetPath(String file) => 'assets/audio/$file';

  Future<void> _configureSession() async {
    try {
      debugPrint('Configuring audio session...');
      final session = await AudioSession.instance;
      debugPrint('Audio session instance obtained');
      
      // iOS: Use ambient so sounds respect the Silent switch (mute/vibrate)
      final config = AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.ambient,
        // ambient mixes by default; keep mixWithOthers to be explicit
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.assistanceSonification,
        ),
        androidWillPauseWhenDucked: false,
      );
      
      debugPrint('Configuring audio session with playback settings');
      await session.configure(config);
      debugPrint('Audio session configured');
      
      // Don't force activation - let the system decide
      debugPrint('Audio session configuration complete');
    } catch (e) {
      debugPrint('Audio session configure error (non-fatal): $e');
      // Don't throw - continue without proper audio session
    }
  }

  void onSettingsChanged() {
    // Live update volumes/session
    final v = settings.volume;
    if (_audioAvailable) {
      _tick.setVolume(v);
      _found.setVolume(v);
      _invalid.setVolume(v);
      _fireworks.setVolume(v);
  _clue.setVolume(v);
  // no select player
    }
    if (!kIsWeb) {
      _configureSession();
    }
  }

  // Manual re-init to debug asset load issues without fallbacks
  Future<void> reinitAll() async {
    if (!kIsWeb) {
      await _configureSession();
    }
    await Future.wait([
      _initializeTickSound(),
      _initializeFoundSound(),
      _initializeInvalidSound(),
      _initializeFireworksSound(),
  _initializeClueSound(),
    ]);
  }

  Future<void> playTick() async {
    debugPrint('playTick called - audioAvailable:$_audioAvailable, soundEnabled:${settings.soundEnabled}');
    if (!settings.soundEnabled) {
      debugPrint('playTick skipped: sound disabled');
      return;
    }
    
    final now = DateTime.now();
    if (now.difference(_lastTickAt) < tickThrottle) {
      debugPrint('playTick throttled');
      return; // debounce
    }
    _lastTickAt = now;

    // Try platform channel first (iOS native)
    if (Platform.isIOS) {
      try {
        await _audioChannel.invokeMethod('playTick');
        debugPrint('Played tick sound via iOS system sound');
        return;
      } catch (e) {
        debugPrint('Failed to play iOS system sound, falling back to just_audio: $e');
      }
    }

    // Fallback to just_audio
    if (_audioAvailable && _tickReady) {
      await _playSound(_tick, label: 'tick', asset: _tickAssetName);
    }
  }

  Future<void> playWordFound() async {
    debugPrint('playWordFound called - audioAvailable:$_audioAvailable, soundEnabled:${settings.soundEnabled}');
    if (!settings.soundEnabled) {
      debugPrint('playWordFound skipped: sound disabled');
      return;
    }

    // Try platform channel first (iOS native)
    if (Platform.isIOS) {
      try {
        await _audioChannel.invokeMethod('playFound');
        debugPrint('Played word found sound via iOS system sound');
        return;
      } catch (e) {
        debugPrint('Failed to play iOS system sound, falling back to just_audio: $e');
      }
    }

    // Fallback to just_audio
    if (_audioAvailable && _foundReady) {
      await _playSound(_found, label: 'found', asset: _foundAssetName);
    }
  }

  Future<void> playInvalid() async {
    debugPrint('playInvalid called - audioAvailable:$_audioAvailable, soundEnabled:${settings.soundEnabled}');
    if (!settings.soundEnabled) {
      debugPrint('playInvalid skipped: sound disabled');
      return;
    }

    // Try platform channel first (iOS native)
    if (Platform.isIOS) {
      try {
        await _audioChannel.invokeMethod('playInvalid');
        debugPrint('Played invalid sound via iOS system sound');
        return;
      } catch (e) {
        debugPrint('Failed to play iOS system sound, falling back to just_audio: $e');
      }
    }

    // Fallback to just_audio
    if (_audioAvailable && _invalidReady) {
      await _playSound(_invalid, label: 'invalid', asset: _invalidAssetName);
    }
  }

  Future<void> playFireworks({Duration? maxDuration}) async {
    debugPrint('playFireworks called - audioAvailable:$_audioAvailable, soundEnabled:${settings.soundEnabled}, _fireworksReady:$_fireworksReady');
    if (!_audioAvailable || !_fireworksReady || !settings.soundEnabled) {
      debugPrint('playFireworks skipped: ${!_audioAvailable ? 'audio not available' : !_fireworksReady ? 'not ready' : 'sound disabled'}');
      return;
    }
    try {
      await _playSound(_fireworks, label: 'fireworks', asset: _fireworksAssetName);
      if (maxDuration != null) {
        // Stop fireworks after the requested duration to cap playback
        Future.delayed(maxDuration, () async {
          try {
            await _fireworks.stop();
          } catch (_) {}
        });
      }
    } catch (e) {
      debugPrint('playFireworks error: $e');
    }
  }

  Future<void> playClue() async {
    debugPrint('playClue called - audioAvailable:$_audioAvailable, soundEnabled:${settings.soundEnabled}, _clueReady:$_clueReady');
    if (!_audioAvailable || !_clueReady || !settings.soundEnabled) {
      debugPrint('playClue skipped: ${!_audioAvailable ? 'audio not available' : !_clueReady ? 'not ready' : 'sound disabled'}');
      return;
    }
    await _playSound(_clue, label: 'clue', asset: _clueAssetName);
  }

  // Debug utility: stop any playing sounds
  Future<void> stopAll() async {
    try {
      await Future.wait([
        _tick.stop(),
        _found.stop(),
        _invalid.stop(),
        _fireworks.stop(),
      ]);
    } catch (_) {}
  }

  // Restart small sample from start for snappy feel
  Future<void> _playSound(AudioPlayer player, {required String label, String? asset}) async {
    if (!_audioAvailable) {
      debugPrint('_playSound: Audio not available');
      return;
    }
    try {
      debugPrint('Seeking audio to start for $label (asset: ${asset ?? 'unknown'})...');
      await player.seek(Duration.zero);
      debugPrint('Starting audio playback for $label...');
      await player.play();
      debugPrint('Audio playback started successfully for $label');
    } catch (e) {
      debugPrint('Error playing sound for $label: ${e.toString()}');
      // Try to reinitialize the audio session on error
      try {
        debugPrint('Attempting to reinitialize audio session for $label...');
        await _configureSession();
        debugPrint('Audio session reconfigured, retrying playback for $label...');
        await player.seek(Duration.zero);
        await player.play();
      } catch (retryError) {
        debugPrint('Failed to recover audio for $label: ${retryError.toString()}');
      }
    }
  }

  // Haptics
  Future<void> hapticSelectLetter() async {
    if (!settings.hapticsEnabled) return;
    try {
      if (Platform.isIOS) {
        await _hapticChannel.invokeMethod('impact', {
          'style': 'heavy',
          'intensity': 0.75,
        });
      } else if (Platform.isAndroid) {
        // Approximate a heavy, mid-intensity tap
        if ((await Vibration.hasVibrator()) == true) {
          Vibration.vibrate(duration: 12, amplitude: 200);
        }
      }
    } catch (_) {}
  }
  
  Future<void> hapticSuccess() async {
    if (!settings.hapticsEnabled) return;
    try {
      if (Platform.isIOS) {
        await _hapticChannel.invokeMethod('notification', {
          'type': 'success',
        });
      } else if (Platform.isAndroid) {
        if (await Vibration.hasCustomVibrationsSupport() ?? false) {
          Vibration.vibrate(pattern: [0, 20, 20, 40], intensities: [0, 150, 0, 220]);
        } else {
          Vibration.vibrate(duration: 40, amplitude: 200);
        }
      }
    } catch (_) {}
  }
  Future<void> hapticLight() async {
    if (!settings.hapticsEnabled) return;
    try {
      if (Platform.isIOS) {
        await HapticFeedback.selectionClick();
      } else if (Platform.isAndroid) {
  if ((await Vibration.hasVibrator()) == true) {
          Vibration.vibrate(duration: 10, amplitude: 128);
        }
      }
    } catch (_) {}
  }

  Future<void> hapticMedium() async {
    if (!settings.hapticsEnabled) return;
    try {
      if (Platform.isIOS) {
        await HapticFeedback.mediumImpact();
      } else if (Platform.isAndroid) {
  if ((await Vibration.hasCustomVibrationsSupport()) == true) {
          // Ensure timings and intensities arrays are equal length to avoid PlatformException
          Vibration.vibrate(
            pattern: [0, 18, 30, 18],
            intensities: [128, 200, 128, 200],
          );
  } else if ((await Vibration.hasVibrator()) == true) {
          Vibration.vibrate(duration: 20);
        }
      }
    } catch (_) {}
  }

  Future<void> hapticHeavy() async {
    if (!settings.hapticsEnabled) return;
    try {
      if (Platform.isIOS) {
        await HapticFeedback.heavyImpact();
      } else if (Platform.isAndroid) {
  if ((await Vibration.hasVibrator()) == true) {
          Vibration.vibrate(duration: 25, amplitude: 255);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tick.dispose();
    _found.dispose();
    _invalid.dispose();
    _fireworks.dispose();
  _clue.dispose();
    super.dispose();
  }
}
