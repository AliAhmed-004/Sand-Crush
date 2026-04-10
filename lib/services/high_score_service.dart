import 'package:hive_flutter/hive_flutter.dart';

/// A service to manage high score persistence using Hive.
class HighScoreService {
  static const String _boxName = 'sand_crush_high_scores';
  static const String _highScoreKey = 'high_score';

  static final HighScoreService _instance = HighScoreService._internal();

  factory HighScoreService() {
    return _instance;
  }

  HighScoreService._internal();

  static HighScoreService get instance => _instance;

  late Box<int> _box;

  /// Initialize Hive and open the high score box.
  /// Call this once during app initialization.
  Future<void> initialize() async {
    _box = await Hive.openBox<int>(_boxName);
  }

  /// Get the current high score. Returns 0 if no high score exists.
  int getHighScore() {
    return _box.get(_highScoreKey, defaultValue: 0) ?? 0;
  }

  /// Save a new high score if it's higher than the current one.
  /// Returns true if the score was saved, false otherwise.
  Future<bool> saveHighScoreIfHigher(int score) async {
    final currentHighScore = getHighScore();
    if (score > currentHighScore) {
      await _box.put(_highScoreKey, score);
      return true;
    }
    return false;
  }

  /// Reset the high score (typically for debugging or testing).
  Future<void> resetHighScore() async {
    await _box.delete(_highScoreKey);
  }
}
