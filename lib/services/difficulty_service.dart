import 'package:flutter/material.dart';
import 'package:sand_crush/services/milestone_service.dart';

/// A service to manage the difficulty settings of the game.
/// 
/// The difficulty is now based on milestones. Each milestone is 25,000 points.
/// Starting with 3 base colors, each milestone unlocks 1 additional color.
class DifficultyService {
  // All available colors in order (total pool to draw from)
  static const List<Color> _allColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
  ];

  // Number of colors available at the start
  static const int _baseColorCount = 3;

  // Singleton pattern
  static final DifficultyService _instance = DifficultyService._internal();

  factory DifficultyService() {
    return _instance;
  }

  DifficultyService._internal();

  static DifficultyService get instance => _instance;

  /// Method to get available colors based on the current milestone level.
  /// Starts with 3 colors and unlocks 1 new color per milestone reached.
  List<Color> getAvailableColors(int score) {
    final unlockedColorCount = MilestoneService.instance.getUnlockedColorCount(
      score,
      _baseColorCount,
    );

    // Clamp to available colors
    final colorCount = unlockedColorCount.clamp(0, _allColors.length);
    return _allColors.sublist(0, colorCount);
  }

  /// Get the current milestone level
  int getCurrentMilestone(int score) {
    return MilestoneService.instance.getCurrentMilestone(score);
  }

  /// Get the score threshold for the next milestone
  int getNextMilestoneScore(int score) {
    return MilestoneService.instance.getNextMilestoneScore(score);
  }
}