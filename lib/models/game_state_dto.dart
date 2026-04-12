import 'package:sand_crush/world.dart';

/// Data Transfer Object for the game state, used for saving and loading the game.
class GameStateDTO {
  final int cols;
  final int rows;
  final List<int> grid; // flattened ARGB values (display colors)
  final List<int> baseColorIds; // base color IDs for matching logic

  GameStateDTO({
    required this.cols,
    required this.rows,
    required this.grid,
    required this.baseColorIds,
  });

  GameStateDTO fromWorld(SandWorld world) {
    return GameStateDTO(
      cols: world.cols,
      rows: world.rows,
      grid: world.gridColorBuffer.toList(),
      baseColorIds: world.baseColorIdBuffer.toList(),
    );
  }
}
