import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_themes.dart';

class SettingsRepository {
  static const _kSound = 'soundEnabled';
  static const _kMusic = 'musicEnabled';
  static const _kHints = 'hintsEnabled';
  static const _kHaptics = 'hapticsEnabled';
  static const _kTheme = 'selectedThemeKey';

  bool soundEnabled = true;
  bool musicEnabled = true; // but UI row disabled
  bool hintsEnabled = true;
  bool hapticsEnabled = true;
  AppTheme theme = AppTheme.hirani;

  Timer? _debounce;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    soundEnabled = sp.getBool(_kSound) ?? true;
    musicEnabled = sp.getBool(_kMusic) ?? true;
    hintsEnabled = sp.getBool(_kHints) ?? true;
    hapticsEnabled = sp.getBool(_kHaptics) ?? true;
    final themeKey = sp.getString(_kTheme) ?? 'Hirani';
    theme = _parseTheme(themeKey);
  }

  Future<void> resetToDefaults() async {
    soundEnabled = true;
    musicEnabled = true;
    hintsEnabled = true;
    hapticsEnabled = true;
    theme = AppTheme.hirani;
    await _saveImmediate();
  }

  void setSound(bool v) {
    soundEnabled = v;
    _debouncedSave();
  }

  void setMusic(bool v) {
    musicEnabled = v;
    _debouncedSave();
  }

  void setHints(bool v) {
    hintsEnabled = v;
    _debouncedSave();
  }

  void setHaptics(bool v) {
    hapticsEnabled = v;
    _debouncedSave();
  }

  void setTheme(AppTheme v) {
    theme = v;
    _debouncedSave();
  }

  void _debouncedSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _saveImmediate);
  }

  Future<void> _saveImmediate() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kSound, soundEnabled);
    await sp.setBool(_kMusic, musicEnabled);
    await sp.setBool(_kHints, hintsEnabled);
    await sp.setBool(_kHaptics, hapticsEnabled);
    await sp.setString(_kTheme, _themeKey(theme));
  }

  static String _themeKey(AppTheme t) {
    switch (t) {
      case AppTheme.bappi:
        return 'Bappi';
      case AppTheme.kashyap:
        return 'Kashyap';
      case AppTheme.hirani:
        return 'Hirani';
    }
  }

  static AppTheme _parseTheme(String key) {
    switch (key.toLowerCase()) {
      case 'bappi':
        return AppTheme.bappi;
      case 'kashyap':
        return AppTheme.kashyap;
      case 'hirani':
      default:
        return AppTheme.hirani;
    }
  }
}
