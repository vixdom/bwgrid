enum AchievementId {
  // Define logical IDs; map them to platform IDs via constants below if needed.
  firstWord,
  fiveWords,
  tenWords,
  firstPuzzle,
}

class Achievements {
  // Google Play Games achievement IDs (configure in Play Console and paste IDs)
  static const Map<AchievementId, String> android = {
    AchievementId.firstWord: 'CgkIXXXXXXXXEAIQAQ',
    AchievementId.fiveWords: 'CgkIXXXXXXXXEAIQAg',
    AchievementId.tenWords: 'CgkIXXXXXXXXEAIQAw',
    AchievementId.firstPuzzle: 'CgkIXXXXXXXXEAIQBA',
  };

  // Apple Game Center achievement IDs (configure in App Store Connect and paste IDs)
  static const Map<AchievementId, String> ios = {
    AchievementId.firstWord: 'first_word',
    AchievementId.fiveWords: 'five_words',
    AchievementId.tenWords: 'ten_words',
    AchievementId.firstPuzzle: 'first_puzzle',
  };
}
