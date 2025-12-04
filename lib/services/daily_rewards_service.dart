import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'wallet_service.dart';

class DailyRewardsService extends ChangeNotifier {
  static final DailyRewardsService _instance = DailyRewardsService._internal();
  static DailyRewardsService get instance => _instance;

  DailyRewardsService._internal();

  static const String _kLastClaimDate = 'bwgrid_daily_last_claim';
  static const String _kCurrentStreak = 'bwgrid_daily_streak';

  // Reward schedule: Day 1 to Day 7
  // "2 tickets for the second time they log in" -> Assuming Day 1 is also 2, or maybe 1?
  // Let's go with [2, 2, 3, 4, 5, 6, 10] based on the prompt's specific mention of "2 tickets for the second time" and "starts again with 2 tickets".
  static const List<int> _rewards = [2, 2, 3, 4, 5, 6, 10];

  int _currentStreak = 0; // 0-indexed, so 0 = Day 1, 6 = Day 7
  DateTime? _lastClaimDate;
  bool _isInitialized = false;

  int get currentDayIndex => _currentStreak % 7;
  int get todayReward => _rewards[currentDayIndex];
  bool get canClaim => _canClaimToday();
  
  // For UI display: returns the reward amount for a specific day index (0-6)
  int getRewardForDay(int index) => _rewards[index % 7];

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _currentStreak = prefs.getInt(_kCurrentStreak) ?? 0;
    final dateStr = prefs.getString(_kLastClaimDate);
    if (dateStr != null) {
      _lastClaimDate = DateTime.parse(dateStr);
    }
    
    _checkStreakReset();
    _isInitialized = true;
    notifyListeners();
  }

  void _checkStreakReset() {
    if (_lastClaimDate == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(_lastClaimDate!.year, _lastClaimDate!.month, _lastClaimDate!.day);

    final difference = today.difference(last).inDays;

    if (difference > 1) {
      // Missed a day (or more), reset streak
      _currentStreak = 0;
    }
    // If difference == 1, it's the next day, streak continues.
    // If difference == 0, it's the same day, streak continues (but can't claim).
  }

  bool _canClaimToday() {
    if (_lastClaimDate == null) return true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(_lastClaimDate!.year, _lastClaimDate!.month, _lastClaimDate!.day);

    return today.isAfter(last);
  }

  Future<void> claimReward() async {
    if (!canClaim) return;

    final reward = todayReward;
    await WalletService.instance.addTickets(reward);

    _lastClaimDate = DateTime.now();
    
    // If we just claimed Day 7 (index 6), the next state should be Day 1 (index 0) of the NEXT cycle.
    // But usually "Streak" implies accumulation.
    // The prompt says: "This resets and the next 7 days starts again".
    // So if I am at index 6 (Day 7), and I claim, I should probably increment streak to 7.
    // My logic `currentDayIndex => _currentStreak % 7` handles the wrapping.
    // So I just increment `_currentStreak`.
    
    _currentStreak++;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCurrentStreak, _currentStreak);
    await prefs.setString(_kLastClaimDate, _lastClaimDate!.toIso8601String());

    notifyListeners();
  }
  
  // Debug method to reset state
  Future<void> debugReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentStreak);
    await prefs.remove(_kLastClaimDate);
    _currentStreak = 0;
    _lastClaimDate = null;
    notifyListeners();
  }
}
