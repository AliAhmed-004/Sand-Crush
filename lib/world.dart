import 'dart:math';

/// This class contains the ACTUAL game state.
/// It knows nothing about screen size, pixels, or UI.
class SandWorld {
  final int cols;
  final int rows;

  /// 2D grid storing whether a cell is filled
  late List<List<bool>> grid;

  /// For optimization: track which cells are active (moving sand)
  Set<Point<int>> activeCells = {};

  SandWorld({required this.cols, required this.rows}) {
    grid = List.generate(rows, (_) => List.generate(cols, (_) => false));
  }

  /// Places a block at a grid position
  void placeCell(int x, int y) {
    if (!isInside(x, y)) return;

    grid[y][x] = true;

    _wake(activeCells, x, y);
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
    final nextGrid = List.generate(
      rows,
      (_) => List.generate(cols, (_) => false),
    );

    final nextActive = <Point<int>>{};
    final rand = Random();

    for (final p in activeCells) {
      final x = p.x;
      final y = p.y;

      if (!isInside(x, y)) continue;
      if (!grid[y][x]) continue;

      final dir = rand.nextBool() ? -1 : 1;

      // try down
      if (isInside(x, y + 1) && !grid[y + 1][x]) {
        nextGrid[y + 1][x] = true;
        _wake(nextActive, x, y + 1);
      }
      // try diagonal
      else if (isInside(x + dir, y + 1) && !grid[y + 1][x + dir]) {
        nextGrid[y + 1][x + dir] = true;
        _wake(nextActive, x + dir, y + 1);
      }
      // stay
      else {
        nextGrid[y][x] = true;
        _wake(nextActive, x, y);
      }
    }

    grid = nextGrid;
    activeCells = nextActive;
  }

  /// Mark a cell and its neighbors as active (for optimization)
  void _wake(Set<Point<int>> set, int x, int y) {
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        final nx = x + dx;
        final ny = y + dy;

        if (isInside(nx, ny)) {
          set.add(Point(nx, ny));
        }
      }
    }
  }
}
