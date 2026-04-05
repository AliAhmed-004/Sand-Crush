import 'dart:math';

/// This class contains the ACTUAL game state.
/// It knows nothing about screen size, pixels, or UI.
class SandWorld {
  final int cols;
  final int rows;

  /// 2D grid storing whether a cell is filled
  late List<List<bool>> grid;

  SandWorld({required this.cols, required this.rows}) {
    grid = List.generate(rows, (_) => List.generate(cols, (_) => false));
  }

  /// Places a block at a grid position
  void placeCell(int x, int y) {
    if (!isInside(x, y)) return;

    grid[y][x] = true;
  }

  /// Check bounds
  bool isInside(int x, int y) {
    return x >= 0 && x < cols && y >= 0 && y < rows;
  }

  /// Update world (for future physics like gravity)
  void update(double dt) {
    applyGravity();
  }

  /// Apply gravity to all cells (placeholder)
  void applyGravity() {
    // Use a 2-grid system
    // One for current state, one for next state
    final nextGrid = List.generate(
      rows,
      (_) => List.generate(cols, (_) => false),
    );

    // Process the current grid and fill the next grid
    for (int y = rows - 1; y >= 0; y--) {
      for (int x = 0; x < cols; x++) {
        if (!grid[y][x]) continue; // Skip empty cells

        // Randomly pick a direction (left or right)
        // if true, try left first; if false, try right first
        final dir = (Random().nextBool()) ? -1 : 1;

        // Try to move down
        if (isInside(x, y + 1) && !grid[y + 1][x]) {
          nextGrid[y + 1][x] = true;
        }
        // If can't move down, try to move diagonally
        else if (isInside(x + dir, y + 1) && !grid[y + 1][x + dir]) {
          nextGrid[y + 1][x + dir] = true;
        }
        // Otherwise, stay in place
        else {
          nextGrid[y][x] = true;
        }
      }
    }

    // Update the grid to the next state
    grid = nextGrid;
  }
}
