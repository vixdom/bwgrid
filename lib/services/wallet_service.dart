import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletService extends ChangeNotifier {
  static final WalletService _instance = WalletService._internal();
  static WalletService get instance => _instance;

  WalletService._internal();

  static const String _kWalletBalance = 'bwgrid_wallet_balance';
  
  int _tickets = 0;
  int get tickets => _tickets;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _tickets = prefs.getInt(_kWalletBalance) ?? 0;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> addTickets(int amount) async {
    if (amount == 0) return;
    _tickets += amount;
    await _save();
    notifyListeners();
  }

  Future<bool> spendTickets(int amount) async {
    if (_tickets >= amount) {
      _tickets -= amount;
      await _save();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kWalletBalance, _tickets);
  }
  
  // Debug/Cheat method
  Future<void> setTickets(int amount) async {
    _tickets = amount;
    await _save();
    notifyListeners();
  }
}
