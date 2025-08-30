import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart';

import '../models/feedback_settings.dart';

/// FeedbackController manages short SFX and haptics with debounce and settings.
/// Provide it via Provider and dispose on app shutdown.
class FeedbackController with ChangeNotifier {
  final FeedbackSettings settings;

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

  FeedbackController(this.settings);
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
    try {
      debugPrint('Initializing tick sound...');
  final d = await _tick.setAsset(_assetPath('select.wav'));
      _tick.setVolume(settings.volume);
      _tickReady = true;
  _tickAssetName = 'select.wav';
  _tickMs = d?.inMilliseconds;
  _tickError = null;
  debugPrint('Tick sound initialized successfully (asset: ${_tickAssetName!}, duration: ${_tickMs ?? -1}ms)');
      notifyListeners();
    } catch (e) {
    final msg = e is PlatformException
      ? 'code=${e.code}, message=${e.message}, details=${e.details}'
      : e.toString();
    debugPrint('Error initializing tick sound: $msg');
      _tickReady = false;
    _tickError = msg;
  notifyListeners();
    }
  }

  Future<void> _initializeFoundSound() async {
  _foundAssetName = 'word_found.wav';
    try {
      debugPrint('Initializing word found sound...');
      final d = await _found.setAsset(_assetPath(_foundAssetName!));
      _found.setVolume(settings.volume);
      _foundReady = true;
      _foundMs = d?.inMilliseconds;
  _foundError = null;
      debugPrint('Word found sound initialized successfully (asset: ${_foundAssetName!}, duration: ${_foundMs ?? -1}ms)');
      notifyListeners();
  } catch (e) {
    final msg = e is PlatformException
      ? 'code=${e.code}, message=${e.message}, details=${e.details}'
      : e.toString();
    debugPrint('Error initializing word found sound for asset ${_foundAssetName!}: $msg');
      _foundReady = false;
      _foundMs = null;
    _foundError = msg;
      notifyListeners();
    }
  }

  Future<void> _initializeInvalidSound() async {
  _invalidAssetName = 'invalid.wav';
    try {
      debugPrint('Initializing invalid sound...');
      final d = await _invalid.setAsset(_assetPath(_invalidAssetName!));
      _invalid.setVolume(settings.volume);
      _invalidReady = true;
      _invalidMs = d?.inMilliseconds;
  _invalidError = null;
      debugPrint('Invalid sound initialized successfully (asset: ${_invalidAssetName!}, duration: ${_invalidMs ?? -1}ms)');
      notifyListeners();
  } catch (e) {
    final msg = e is PlatformException
      ? 'code=${e.code}, message=${e.message}, details=${e.details}'
      : e.toString();
    debugPrint('Error initializing invalid sound for asset ${_invalidAssetName!}: $msg');
      _invalidReady = false;
      _invalidMs = null;
    _invalidError = msg;
      notifyListeners();
    }
  }

  Future<void> _initializeFireworksSound() async {
    try {
      debugPrint('Initializing fireworks sound...');
  final d = await _fireworks.setAsset(_assetPath('fireworks.wav'));
      _fireworks.setVolume(settings.volume);
      _fireworksReady = true;
  _fireworksAssetName = 'fireworks.wav';
  _fireworksMs = d?.inMilliseconds;
  _fireworksError = null;
  debugPrint('Fireworks sound initialized successfully (asset: ${_fireworksAssetName!}, duration: ${_fireworksMs ?? -1}ms)');
  notifyListeners();
  } catch (e) {
    final msg = e is PlatformException
      ? 'code=${e.code}, message=${e.message}, details=${e.details}'
      : e.toString();
    debugPrint('Error initializing fireworks sound: $msg');
      _fireworksReady = false;
    _fireworksError = msg;
  notifyListeners();
    }
  }

  Future<void> _initializeClueSound() async {
    try {
      debugPrint('Initializing clue sound...');
      final d = await _clue.setAsset(_assetPath('clue.wav'));
      _clue.setVolume(settings.volume);
      _clueReady = true;
      _clueAssetName = 'clue.wav';
      _clueMs = d?.inMilliseconds;
      _clueError = null;
      debugPrint('Clue sound initialized successfully (asset: ${_clueAssetName!}, duration: ${_clueMs ?? -1}ms)');
      notifyListeners();
    } catch (e) {
      final msg = e is PlatformException
          ? 'code=${e.code}, message=${e.message}, details=${e.details}'
          : e.toString();
      debugPrint('Error initializing clue sound: $msg');
      _clueReady = false;
      _clueError = msg;
      notifyListeners();
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

  void _initializeAudioInBackground() async {
    try {
      debugPrint('Configuring audio session in background...');
      await _configureSession();
      
      // Initialize sounds in parallel for faster startup, but don't await
      debugPrint('Initializing sound effects in background...');
      unawaited(_initializeTickSound());
      unawaited(_initializeFoundSound());
      unawaited(_initializeInvalidSound());
      unawaited(_initializeFireworksSound());
      unawaited(_initializeClueSound());
      
      _audioAvailable = true;
      debugPrint('FeedbackController initialized. Audio available: $_audioAvailable');
      
    } catch (e) {
      _audioAvailable = false;
      debugPrint('Error initializing FeedbackController: $e');
    }
  }

  // Helper method for unawaited futures
  void unawaited(Future<void> future) {
    future.catchError((error) {
      debugPrint('Background audio initialization error: $error');
    });
  }

  String _assetPath(String file) => 'assets/audio/$file';

  Future<void> _configureSession() async {
    try {
      debugPrint('Configuring audio session...');
      final session = await AudioSession.instance;
      debugPrint('Audio session instance obtained');
      
      // Use more permissive settings that work better on iOS simulator
      final config = AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.ambient,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.assistanceSonification,
        ),
        androidWillPauseWhenDucked: false,
      );
      
      debugPrint('Configuring audio session with ambient settings');
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
    debugPrint('playTick called - audioAvailable:$_audioAvailable, soundEnabled:${settings.soundEnabled}, _tickReady:$_tickReady');
    if (!_audioAvailable || !_tickReady || !settings.soundEnabled) {
      debugPrint('playTick skipped: ${!_audioAvailable ? 'audio not available' : !_tickReady ? 'not ready' : 'sound disabled'}');
      // Try to reinitialize if not ready
      if (!_tickReady) {
        debugPrint('Attempting to reload tick sound...');
        await _initializeTickSound();
        if (_tickReady) {
          debugPrint('Successfully reloaded tick sound, playing...');
          return await _playSound(_tick, label: 'tick', asset: _tickAssetName);
        }
      }
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastTickAt) < tickThrottle) {
      debugPrint('playTick throttled');
      return; // debounce
    }
    _lastTickAt = now;
  await _playSound(_tick, label: 'tick', asset: _tickAssetName);
  }

  Future<void> playWordFound() async {
    debugPrint('playWordFound called - audioAvailable:$_audioAvailable, soundEnabled:${settings.soundEnabled}, _foundReady:$_foundReady');
    if (!_audioAvailable || !_foundReady || !settings.soundEnabled) {
      debugPrint('playWordFound skipped: ${!_audioAvailable ? 'audio not available' : !_foundReady ? 'not ready' : 'sound disabled'}');
      return;
    }
    await _playSound(_found, label: 'found', asset: _foundAssetName);
  }

  Future<void> playInvalid() async {
    debugPrint('playInvalid called - audioAvailable:$_audioAvailable, soundEnabled:${settings.soundEnabled}, _invalidReady:$_invalidReady');
    if (!_audioAvailable || !_invalidReady || !settings.soundEnabled) {
      debugPrint('playInvalid skipped: ${!_audioAvailable ? 'audio not available' : !_invalidReady ? 'not ready' : 'sound disabled'}');
      return;
    }
    await _playSound(_invalid, label: 'invalid', asset: _invalidAssetName);
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
          'intensity': 0.5,
        });
      } else if (Platform.isAndroid) {
        // Approximate a heavy, mid-intensity tap
        if ((await Vibration.hasVibrator()) == true) {
          Vibration.vibrate(duration: 12, amplitude: 200);
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
          Vibration.vibrate(pattern: [0, 18, 30, 18], intensities: [128, 200, 128]);
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
