import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:sand_crush/world.dart';

class SandGame extends FlameGame with TapCallbacks {
  late SandWorld sandWorld;

  final double topUIRatio = 0.2;
  final double bottomUIRatio = 0.2;

  double cellSize = 1;
  late Offset gridOffset;

  final int cols = 40;
  final int rows = 40;

  final Paint cellPaint = Paint()..color = Colors.orange;

  double _accumulator = 0;
  static const double _step = 1 / 20;

  @override
  Future<void> onLoad() async {
    sandWorld = SandWorld(cols: cols, rows: rows);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    final topUIHeight = size.y * topUIRatio;
    final bottomUIHeight = size.y * bottomUIRatio;

    final playableHeight = size.y - topUIHeight - bottomUIHeight;
    final playableWidth = size.x;

    final cellWidth = playableWidth / cols;
    final cellHeight = playableHeight / rows;

    cellSize = cellWidth < cellHeight ? cellWidth : cellHeight;

    final gridWidth = cols * cellSize;
    final gridHeight = rows * cellSize;

    gridOffset = Offset(
      (size.x - gridWidth) / 2,
      topUIHeight + (playableHeight - gridHeight) / 2,
    );
  }

  // =========================================================
  // INPUT (FIXED)
  // =========================================================

  @override
  void onTapDown(TapDownEvent event) {
    final pos = event.localPosition;

    final gridX = ((pos.x - gridOffset.dx) / cellSize).floor();
    final gridY = ((pos.y - gridOffset.dy) / cellSize).floor();

    if (!sandWorld.isInside(gridX, gridY)) return;

    sandWorld.placeShape(_randomShape(), gridX, gridY);
  }

  /// Generates a simple test shape (Tetris-like)
  List<Point<int>> _randomShape() {
    final shapes = [
      // square
      [Point(0, 0), Point(1, 0), Point(0, 1), Point(1, 1)],

      // line
      [Point(0, 0), Point(1, 0), Point(2, 0), Point(3, 0)],

      // L shape
      [Point(0, 0), Point(0, 1), Point(0, 2), Point(1, 2)],
    ];

    return shapes[DateTime.now().millisecond % shapes.length];
  }

  // =========================================================
  // UPDATE LOOP
  // =========================================================

  @override
  void update(double dt) {
    super.update(dt);

    _accumulator += dt;

    while (_accumulator >= _step) {
      sandWorld.update(_step);
      _accumulator -= _step;
    }
  }

  // =========================================================
  // RENDERING (UNCHANGED - STILL VALID)
  // =========================================================

  @override
  void render(Canvas canvas) {
    super.render(canvas);

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
