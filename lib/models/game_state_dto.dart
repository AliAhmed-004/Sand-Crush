import 'package:sand_crush/world.dart';

/// Data Transfer Object for the game state, used for saving and loading the game.
class GameStateDTO {
  final int cols;
  final int rows;
  final List<int> grid; // flattened ARGB values

  GameStateDTO({required this.cols, required this.rows, required this.grid});

  GameStateDTO fromWorld(SandWorld world) {
    return GameStateDTO(
      cols: world.cols,
      rows: world.rows,
      grid: world.gridColorBuffer.toList(),
    );
  }
}
