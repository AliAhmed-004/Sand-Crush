import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:sand_crush/world.dart';

class SandGame extends FlameGame with TapCallbacks {
  late SandWorld sandWorld;

  final double topUIRatio = 0.2;
  final double bottomUIRatio = 0.2;

  double cellSize = 1;
  late Offset gridOffset;

  final int cols = 80;
  final int rows = 80;

  static final List<Color> colors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
  ];

  // Pick a random color for the cell paint
  final Paint cellPaint = Paint()..color = colors.random();

  double _accumulator = 0;
  static const double _step = 1 / 30;

  bool _wasStableLastFrame = true;

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

    final randomColor =
        colors[Random().nextInt(colors.length)]; // ← safe & explicit

    sandWorld.placeShape(_randomShape(), gridX, gridY, randomColor);
  }

  /// Generates a scaled Tetris-like test shape that looks the same size
  /// on any grid dimensions (cols × rows).
  List<Point<int>> _randomShape() {
    final shapes = [
      // square
      [Point(0, 0), Point(1, 0), Point(0, 1), Point(1, 1)],
      // line
      [Point(0, 0), Point(1, 0), Point(2, 0), Point(3, 0)],
      // L shape
      [Point(0, 0), Point(0, 1), Point(0, 2), Point(1, 2)],
    ];

    final baseShape = shapes[DateTime.now().millisecond % shapes.length];

    // Dynamic scale based on grid width (you can tweak the divisor)
    // Assuming a "standard" Tetris board of ~10 columns where the original
    // shapes felt the right size. For cols=40 this gives scale=4.
    int scale = cols ~/ 15; // 40 → 4
    if (scale < 1) scale = 1; // safety for very small grids

    // Optional: make it respect both dimensions (keeps aspect nice)
    // scale = math.min(scale, rows ~/ 20);   // add if you import dart:math

    return _scaleShape(baseShape, scale);
  }

  /// Expands each cell of a base shape into a solid scale×scale block.
  List<Point<int>> _scaleShape(List<Point<int>> base, int scale) {
    final scaled = <Point<int>>[];
    for (final p in base) {
      for (int dy = 0; dy < scale; dy++) {
        for (int dx = 0; dx < scale; dx++) {
          scaled.add(Point(p.x * scale + dx, p.y * scale + dy));
        }
      }
    }
    return scaled;
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

    // Only check bridges when the board has just become stable
    if (sandWorld.isStable && !_wasStableLastFrame) {
      for (final c in colors) {
        if (sandWorld.clearSpanningBridge(c)) {
          print('🚀 $c has formed a left-to-right bridge!');
        }
      }
    }

    _wasStableLastFrame = sandWorld.isStable;
  }

  // =========================================================
  // RENDERING (UNCHANGED - STILL VALID)
  // =========================================================

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final cellColor = sandWorld.grid[y][x];
        if (cellColor == null) continue;

        final rect = Rect.fromLTWH(
          gridOffset.dx + x * cellSize,
          gridOffset.dy + y * cellSize,
          cellSize,
          cellSize,
        );

        final paint = Paint()..color = cellColor; // ← per-cell color
        canvas.drawRect(rect, paint);
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
