import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:sand_crush/world.dart';

class SandGame extends FlameGame with TapCallbacks {
  late SandWorld sandWorld;

  final double topUIRatio = 0.2; // 20% for HUD
  final double bottomUIRatio = 0.2; // 20% for preview

  /// Size of each grid cell in pixels
  double cellSize = 1;

  /// Offset to center the grid on screen
  late Offset gridOffset;

  /// Grid dimensions
  final int cols = 40;
  final int rows = 40;

  final Paint cellPaint = Paint()..color = Colors.orange;

  double _accumulator = 0;
  static const double _step = 1 / 30; // 30 sim steps per second

  @override
  Future<void> onLoad() async {
    sandWorld = SandWorld(cols: cols, rows: rows);
  }

  /// Called whenever screen size changes
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    final topUIHeight = size.y * topUIRatio;
    final bottomUIHeight = size.y * bottomUIRatio;

    final playableHeight = size.y - topUIHeight - bottomUIHeight;
    final playableWidth = size.x;

    // Now fit grid INSIDE this area
    final cellWidth = playableWidth / cols;
    final cellHeight = playableHeight / rows;

    // Pick the smaller one to maintain square cells
    cellSize = cellWidth < cellHeight ? cellWidth : cellHeight;

    final gridWidth = cols * cellSize;
    final gridHeight = rows * cellSize;

    // Center grid horizontally and vertically within playable area
    gridOffset = Offset(
      (size.x - gridWidth) / 2,
      topUIHeight + (playableHeight - gridHeight) / 2,
    );
  }

  /// Handle tap input
  @override
  void onTapDown(TapDownEvent event) {
    final pos = event.localPosition;

    // Convert screen → grid
    final gridX = ((pos.x - gridOffset.dx) / cellSize).floor();
    final gridY = ((pos.y - gridOffset.dy) / cellSize).floor();

    sandWorld.placeCell(gridX, gridY);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _accumulator += dt;

    while (_accumulator >= _step) {
      sandWorld.update(_step);
      _accumulator -= _step;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw grid cells
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        if (!sandWorld.grid[y][x]) continue;

        final rect = Rect.fromLTWH(
          gridOffset.dx + x * cellSize,
          gridOffset.dy + y * cellSize,
          cellSize,
          cellSize,
        );

        canvas.drawRect(rect, cellPaint);
      }
    }

    // Optional: draw grid lines (debug)
    _drawGridLines(canvas);
  }

  void _drawGridLines(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke;

    for (int x = 0; x <= cols; x++) {
      final dx = gridOffset.dx + x * cellSize;
      canvas.drawLine(
        Offset(dx, gridOffset.dy),
        Offset(dx, gridOffset.dy + rows * cellSize),
        paint,
      );
    }

    for (int y = 0; y <= rows; y++) {
      final dy = gridOffset.dy + y * cellSize;
      canvas.drawLine(
        Offset(gridOffset.dx, dy),
        Offset(gridOffset.dx + cols * cellSize, dy),
        paint,
      );
    }
  }
}
