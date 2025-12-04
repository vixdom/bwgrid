import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/daily_rewards_service.dart';
import '../widgets/glass_surface.dart';

class DailyChallengeScreen extends StatelessWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Assumes stacked on a background
      body: Stack(
        children: [
          // Background (if not provided by parent, we can add one, but usually this is pushed over existing)
          // For now, let's assume it's a modal or full screen with its own background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F3460), Color(0xFF16213E)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Daily Rewards',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Balance close button
                    ],
                  ),
                ),
                
                Expanded(
                  child: Consumer<DailyRewardsService>(
                    builder: (context, rewards, child) {
                      return Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Come back every day to earn tickets!',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              // Days Grid
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: List.generate(7, (index) {
                                  final dayNum = index + 1;
                                  final rewardAmount = rewards.getRewardForDay(index);
                                  final currentDayIndex = rewards.currentDayIndex;
                                  
                                  // Determine state
                                  // If index < currentDayIndex: Claimed (unless streak reset logic implies otherwise, but here we visualize the cycle)
                                  // Actually, currentDayIndex is the *next* day to claim.
                                  // So if currentDayIndex is 2 (Day 3), then 0 and 1 are claimed.
                                  // Wait, if I claim today, currentDayIndex increments.
                                  // So if I just claimed Day 1, currentDayIndex becomes 1 (Day 2).
                                  // So index < currentDayIndex means claimed.
                                  // index == currentDayIndex means "Today" (or next up).
                                  // But if I *haven't* claimed today yet?
                                  // The service increments *after* claiming.
                                  // So if I haven't claimed, currentDayIndex points to the day I am about to claim.
                                  // If I *have* claimed, currentDayIndex points to tomorrow.
                                  // But the UI needs to show "Today (Claimed)" vs "Today (Unclaimed)".
                                  // The service doesn't expose "claimed today" boolean directly, but `canClaim` tells us.
                                  // If `canClaim` is true, currentDayIndex is TODAY.
                                  // If `canClaim` is false, currentDayIndex is TOMORROW (so the previous index was today).
                                  
                                  bool isClaimed = index < currentDayIndex;
                                  bool isToday = index == currentDayIndex;
                                  
                                  // Correction: If !canClaim, it means we already claimed for the current streak count.
                                  // So `currentDayIndex` is actually the *next* day.
                                  // So the day we just claimed is `currentDayIndex - 1`.
                                  // So if !canClaim:
                                  //   index < currentDayIndex : Claimed (including today)
                                  //   index == currentDayIndex : Tomorrow (Locked)
                                  
                                  // If canClaim:
                                  //   index < currentDayIndex : Claimed
                                  //   index == currentDayIndex : Today (Available)
                                  
                                  // Visual states:
                                  // 1. Claimed (Green check)
                                  // 2. Available (Highlight, "Claim")
                                  // 3. Locked (Gray)
                                  
                                  bool isLocked = index > currentDayIndex;
                                  
                                  Color bgColor = Colors.white.withOpacity(0.1);
                                  Color borderColor = Colors.white.withOpacity(0.2);
                                  IconData? icon;
                                  
                                  if (isClaimed) {
                                    bgColor = Colors.green.withOpacity(0.2);
                                    borderColor = Colors.green;
                                    icon = Icons.check_circle;
                                  } else if (isToday && rewards.canClaim) {
                                    bgColor = Colors.amber.withOpacity(0.2);
                                    borderColor = Colors.amber;
                                  } else {
                                    // Locked
                                    icon = Icons.lock_outline;
                                  }

                                  return Container(
                                    width: 100,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: borderColor, width: 2),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Day $dayNum',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (icon != null && isClaimed)
                                          Icon(icon, color: Colors.green, size: 32)
                                        else if (icon != null && !isClaimed)
                                          Icon(icon, color: Colors.white30, size: 32)
                                        else
                                          const Icon(Icons.confirmation_number, color: Colors.amber, size: 32),
                                        
                                        const SizedBox(height: 8),
                                        Text(
                                          '+$rewardAmount',
                                          style: const TextStyle(
                                            color: Colors.amber,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                              
                              const SizedBox(height: 48),
                              
                              // Claim Button
                              SizedBox(
                                width: 200,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: rewards.canClaim
                                      ? () {
                                          rewards.claimReward();
                                          // Optional: Show confetti or sound
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    disabledBackgroundColor: Colors.white10,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: Text(
                                    rewards.canClaim ? 'CLAIM' : 'COME BACK TOMORROW',
                                    style: TextStyle(
                                      color: rewards.canClaim ? Colors.black : Colors.white38,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
