/// A service to manage the scoring system of the game.
///
/// Each placement of a block rewards base_points
/// Each cleared pile of sand rewards base_points * multiplier
/// The multiplier is based on the size of the pile cleared, minimum is 2
class ScoringService {
  // Base points awarded for placing a block or clearing a pile of sand
  final int _basePoints = 25;
  final int _pileMultiplier = 2;
  final int _comboMultiplier = 1;

  // Total score of the player
  int totalScore = 0;

  int get currentScore => totalScore;
  int get comboMultiplier => _comboMultiplier;

  // Singleton pattern
  static final ScoringService _instance = ScoringService._internal();
  
  factory ScoringService() {
    return _instance;
  }
  
  ScoringService._internal();
  
  static ScoringService get instance => _instance;


  /// Method to add points for placing a block
  void addBlockPlacementPoints() {
    totalScore += _basePoints;

    print('Block placed! Current score: $totalScore');
  }

  /// Method to add points for clearing a pile of sand
  void addSandClearPoints(int pilesCleared, int pileSize) {
    int multiplier = pileSize >= 2 ? pileSize : _pileMultiplier;
    totalScore += _basePoints * multiplier * pilesCleared;

    print('Cleared $pilesCleared pile(s) of size $pileSize! Current score: $totalScore');
  }

  /// Method to reset the score, typically called when starting a new game
  void resetScore() {
    totalScore = 0;
  }

  /// Method to calculate the score for a combo, where multiple piles are cleared in a single move
  void addComboPoints(int comboCount) {
    if (comboCount > 1) {
      totalScore += _basePoints * _comboMultiplier * comboCount;

      print('Combo of $comboCount! Current score: $totalScore');
    }
  }
}
