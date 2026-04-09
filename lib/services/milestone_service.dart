/// A service to manage game milestones.
///
/// Each milestone is reached at 25000 point intervals.
/// Milestone 0: 0-25,000 points
/// Milestone 1: 25,001-50,000 points
/// Milestone 2: 50,001-75,000 points
/// And so on...
class MilestoneService {
  static const int _milestoneThreshold = 25000;

  // Singleton pattern
  static final MilestoneService _instance = MilestoneService._internal();

  factory MilestoneService() {
    return _instance;
  }

  MilestoneService._internal();

  static MilestoneService get instance => _instance;

  /// Gets the current milestone level based on score.
  /// Each milestone is 25,000 points apart.
  int getCurrentMilestone(int score) {
    return score ~/ _milestoneThreshold;
  }

  /// Gets the score threshold for the next milestone.
  int getNextMilestoneScore(int score) {
    final currentMilestone = getCurrentMilestone(score);
    return (currentMilestone + 1) * _milestoneThreshold;
  }

  /// Gets the score threshold for a specific milestone.
  int getMilestoneScore(int milestoneLevel) {
    return milestoneLevel * _milestoneThreshold;
  }

  /// Calculates how many colors should be unlocked based on milestone.
  /// Starts with baseColors and adds 1 for each milestone reached.
  int getUnlockedColorCount(int score, int baseColors) {
    final milestone = getCurrentMilestone(score);
    return baseColors + milestone;
  }
}
