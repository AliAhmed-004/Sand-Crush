import 'package:flutter/material.dart';

/// A service to manage the difficulty settings of the game.
/// 
/// The difficulty depends on the score
/// 
/// Easy: 0-1000 points -> 3 colors of the blocks
/// Medium: 1000-5000 points -> all colors from previous difficulty + 1 new color
/// Hard: 5000+ points -> all colors from previous difficulty + 1 new color
class DifficultyService {
  // All available colors (ordered by difficulty tier)
  static const List<Color> _easyColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
  ];

  static const List<Color> _mediumColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
  ];

  static const List<Color> _hardColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
  ];

  // Singleton pattern
  static final DifficultyService _instance = DifficultyService._internal();
  
  factory DifficultyService() {
    return _instance;
  }
  
  DifficultyService._internal();
  
  static DifficultyService get instance => _instance;

  /// Method to get the current difficulty level based on the score
  DifficultyLevel getDifficultyLevel(int score) {
    if (score < 1000) {
      return DifficultyLevel.easy;
    } else if (score < 5000) {
      return DifficultyLevel.medium;
    } else {
      return DifficultyLevel.hard;
    }
  }

  /// Method to get available colors based on the current difficulty level
  List<Color> getAvailableColors(int score) {
    final difficulty = getDifficultyLevel(score);
    switch (difficulty) {
      case DifficultyLevel.easy:
        return _easyColors;
      case DifficultyLevel.medium:
        return _mediumColors;
      case DifficultyLevel.hard:
        return _hardColors;
    }
  }
}

/// Enum to represent the different difficulty levels in a more structured way
enum DifficultyLevel {
  easy,
  medium,
  hard
}