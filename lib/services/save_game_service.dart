import 'package:hive/hive.dart';
import 'package:sand_crush/config/game_config.dart';
import 'package:sand_crush/models/game_state_dto.dart';

/// Service responsible for saving and loading the game state from Hive storage.
///
/// Uses [GameStateDTO] to serialize the game state for persistence.
class SaveGameService {
  static final SaveGameService _instance = SaveGameService._internal();

  factory SaveGameService() {
    return _instance;
  }

  SaveGameService._internal();

  static SaveGameService get instance => _instance;

  late Box _box;
  bool _isSaving = false;
  Map<String, dynamic>? _pendingState;

  /// Initialize Hive and open the game state box.
  /// Call this once during app initialization.
  Future<void> initialize() async {
    _box = await Hive.openBox(GameConfig.gameStateBox);
  }

  // Method to save the game state to Hive
  Future<void> saveGame(GameStateDTO gameState, int score) async {
    final state = {
      'cols': gameState.cols,
      'rows': gameState.rows,
      'grid': gameState.grid,
      'baseColorIds': gameState.baseColorIds,
      'score': score,
    };

    _pendingState = state;
    if (_isSaving) {
      return;
    }

    _isSaving = true;
    try {
      while (_pendingState != null) {
        final stateToWrite = _pendingState!;
        _pendingState = null;
        await _box.put(GameConfig.savedGameStateKey, stateToWrite);
      }
    } finally {
      _isSaving = false;
    }
  }

  // Method to load the game state from Hive. Returns null if no saved state exists.
  Map<String, dynamic>? loadGame() {
    final data = _box.get(GameConfig.savedGameStateKey);
    if (data == null) return null;
    
    // Cast the map properly from Map<dynamic, dynamic> to Map<String, dynamic>
    return Map<String, dynamic>.from(data as Map);
  }

  // Method to check if a saved game exists
  bool hasSavedGame() {
    return _box.containsKey(GameConfig.savedGameStateKey);
  }

  // Method to get the score from the saved game
  int? getSavedScore() {
    final data = _box.get(GameConfig.savedGameStateKey);
    if (data == null) return null;
    try {
      return (data as Map)['score'] as int?;
    } catch (e) {
      return null;
    }
  }

  // Method to delete the saved game
  Future<void> deleteSavedGame() async {
    await _box.delete(GameConfig.savedGameStateKey);
  }
}
