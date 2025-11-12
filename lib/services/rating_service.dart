import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service to manage in-app rating prompts and feedback collection
class RatingService {
  static const String _keyRatingPromptCount = 'rating_prompt_count';
  static const String _keyHasRated = 'has_rated';
  static const String _keyScreensCompleted = 'screens_completed_for_rating';
  static const int _maxPrompts = 3; // Show up to 3 times
  
  final InAppReview _inAppReview = InAppReview.instance;

  /// Check if we should show the rating prompt after completing a screen
  Future<bool> shouldShowRatingPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Don't show if user has already rated
    final hasRated = prefs.getBool(_keyHasRated) ?? false;
    if (hasRated) return false;
    
    // Check how many times we've shown the prompt
    final promptCount = prefs.getInt(_keyRatingPromptCount) ?? 0;
    if (promptCount >= _maxPrompts) return false;
    
    // Check if they've completed a screen that triggers the prompt (screens 1, 2, or 3)
    final screensCompleted = prefs.getInt(_keyScreensCompleted) ?? 0;
    
    return screensCompleted > 0 && screensCompleted <= _maxPrompts;
  }

  /// Mark that a screen has been completed
  Future<void> markScreenCompleted(int screenNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_keyScreensCompleted) ?? 0;
    
    // Only increment if this is a new milestone (1, 2, or 3)
    if (screenNumber > currentCount && screenNumber <= _maxPrompts) {
      await prefs.setInt(_keyScreensCompleted, screenNumber);
    }
  }

  /// Increment the prompt counter
  Future<void> _incrementPromptCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_keyRatingPromptCount) ?? 0;
    await prefs.setInt(_keyRatingPromptCount, count + 1);
  }

  /// Mark that the user has provided a rating
  Future<void> markAsRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasRated, true);
  }

  /// Show the custom rating dialog with stars
  Future<void> showRatingDialog(BuildContext context) async {
    await _incrementPromptCount();
    
    if (!context.mounted) return;
    
    int selectedRating = 0;
    
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            '🎬 Enjoying BollyWord?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your feedback helps us improve!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    iconSize: 40,
                    icon: Icon(
                      starIndex <= selectedRating
                          ? Icons.star
                          : Icons.star_border,
                      color: starIndex <= selectedRating
                          ? Colors.amber
                          : Colors.grey,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        selectedRating = starIndex;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 10),
              if (selectedRating > 0)
                Text(
                  selectedRating >= 4 ? 'Thank you! 🎉' : 'Thanks for your input',
                  style: TextStyle(
                    fontSize: 12,
                    color: selectedRating >= 4 ? Colors.green : Colors.orange,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Maybe Later'),
            ),
            if (selectedRating > 0)
              FilledButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _handleRating(context, selectedRating);
                },
                child: const Text('Submit'),
              ),
          ],
        ),
      ),
    );
  }

  /// Handle the rating based on star count
  Future<void> _handleRating(BuildContext context, int rating) async {
    await markAsRated();
    
    if (rating >= 4) {
      // Good rating: Try to show native store review
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      } else {
        // Fallback: Open store page directly
        await _openStorePage();
      }
    } else {
      // Lower rating: Show feedback form
      if (context.mounted) {
        await _showFeedbackForm(context);
      }
    }
  }

  /// Show feedback form for lower ratings
  Future<void> _showFeedbackForm(BuildContext context) async {
    final TextEditingController feedbackController = TextEditingController();
    
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text(
          'Help Us Improve',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'What could we do better?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Your suggestions...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () {
              // Here you could send feedback to your backend/email
              // For now, just save it locally or log it
              debugPrint('📝 User feedback: ${feedbackController.text}');
              Navigator.of(context).pop();
              
              // Show thank you message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for your feedback! 🙏'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    
    feedbackController.dispose();
  }

  /// Open the app store page
  Future<void> _openStorePage() async {
    // Replace with your actual App Store and Play Store IDs
    const String appStoreId = '6751748862'; // Provided Apple App Store ID
    const String playStoreId = 'com.moviemasala.wordsearch'; // Android applicationId
    
    try {
      // For iOS
      final Uri appStoreUrl = Uri.parse('https://apps.apple.com/app/id$appStoreId');
      // For Android
      final Uri playStoreUrl = Uri.parse('https://play.google.com/store/apps/details?id=$playStoreId');
      
      // Try iOS first, then Android
      if (await canLaunchUrl(appStoreUrl)) {
        await launchUrl(appStoreUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(playStoreUrl)) {
        await launchUrl(playStoreUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('❌ Error opening store page: $e');
    }
  }
}
