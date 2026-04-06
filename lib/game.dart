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

  // Fixed timestep accumulator
  double _accumulator = 0;
  static const double _step = 1 / 60;

  // Track stability to trigger bridge checks only when the board transitions from unstable to stable
  bool _wasStableLastFrame = true;

  // Next piece preview
  late List<Point<int>> nextShape;
  late Color nextColor;

  // Preview UI settings
  final double previewSize = 120.0; // size of the preview box in pixels
  final int previewGridSize = 6; // small grid (e.g. 6x6) for preview

  @override
  Future<void> onLoad() async {
    sandWorld = SandWorld(cols: cols, rows: rows);
    _generateNextPiece();
  }

  void _generateNextPiece() {
    nextShape = _randomShape();
    nextColor = colors[Random().nextInt(colors.length)];
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
    if (!sandWorld.isStable) return; // prevent new shapes while unstable

    // Convert tap position to grid coordinates
    final pos = event.localPosition;
    final gridX = ((pos.x - gridOffset.dx) / cellSize).floor();
    final gridY = ((pos.y - gridOffset.dy) / cellSize).floor();

    // check if tap is within grid bounds
    if (!sandWorld.isInside(gridX, gridY)) return;

    sandWorld.placeShape(nextShape, gridX, gridY, nextColor);

    // Generate the next one immediately
    _generateNextPiece();
  }

  /// Generates a scaled Tetris-like test shape that looks the same size
  /// on any grid dimensions (cols × rows).
  List<Point<int>> _randomShape() {
    final shapes = [
      // O (square) - already perfectly centered
      [Point(-1, -1), Point(0, -1), Point(-1, 0), Point(0, 0)],

      // I (line) horizontal - centered
      [Point(-2, 0), Point(-1, 0), Point(0, 0), Point(1, 0)],

      // L shape - centered as well as possible on a 4-block piece
      [Point(-1, -1), Point(-1, 0), Point(-1, 1), Point(0, 1)],
    ];

    final baseShape = shapes[DateTime.now().millisecond % shapes.length];

    // Keep your nice dynamic scaling
    int scale = cols ~/ 15;
    if (scale < 1) scale = 1;

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
    _drawNextPiecePreview(canvas);
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

  void _drawNextPiecePreview(Canvas canvas) {
    // Position: bottom center
    final previewX = (size.x - previewSize) / 2;
    final previewY = size.y - previewSize - 40;

    // Background box
    final bgRect = Rect.fromLTWH(previewX, previewY, previewSize, previewSize);
    canvas.drawRect(
      bgRect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill,
    );

    // Border
    canvas.drawRect(
      bgRect,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // "NEXT" title
    final textPainter = TextPainter(
      text: const TextSpan(
        text: "NEXT",
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(previewX + (previewSize - textPainter.width) / 2, previewY - 28),
    );

    if (nextShape.isEmpty) return;

    // === KEY CHANGE: Use the SAME cellSize as the main grid ===
    final previewCellSize = cellSize; // ← This makes it match perfectly

    // Find bounds of the shape
    final minX = nextShape.map((p) => p.x).reduce((a, b) => a < b ? a : b);
    final maxX = nextShape.map((p) => p.x).reduce((a, b) => a > b ? a : b);
    final minY = nextShape.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    final maxY = nextShape.map((p) => p.y).reduce((a, b) => a > b ? a : b);

    final shapeWidth = maxX - minX + 1;
    final shapeHeight = maxY - minY + 1;

    // Center the shape inside the preview box
    final totalShapeWidth = shapeWidth * previewCellSize;
    final totalShapeHeight = shapeHeight * previewCellSize;

    final offsetX =
        previewX + (previewSize - totalShapeWidth) / 2 - minX * previewCellSize;
    final offsetY =
        previewY +
        (previewSize - totalShapeHeight) / 2 -
        minY * previewCellSize;

    // Draw the shape using the same cell size as the main grid
    final paint = Paint()..color = nextColor;

    for (final p in nextShape) {
      final drawX = offsetX + p.x * previewCellSize;
      final drawY = offsetY + p.y * previewCellSize;

      final rect = Rect.fromLTWH(
        drawX,
        drawY,
        previewCellSize,
        previewCellSize,
      );
      canvas.drawRect(rect, paint);
    }
  }
}
