import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:sand_crush/config/game_config.dart';
import 'package:sand_crush/services/difficulty_service.dart';
import 'package:sand_crush/services/milestone_service.dart';
import 'package:sand_crush/services/scoring_service.dart';
import 'package:sand_crush/world.dart';

class SandGame extends FlameGame with TapCallbacks {
  late SandWorld sandWorld;

  final double topUIRatio = 0.2;
  final double bottomUIRatio = 0.2;
  final double horizontalPadding = 20.0;

  double cellSize = 1;
  late Offset gridOffset;

  final int cols = 80;
  final int rows = 100;

  // All colors available at max difficulty
  static final List<Color> colors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
  ];

  // Batched rendering buffers
  late Float32List _vertices;
  late Int32List _colors;

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

  bool _isLoaded = false;

  // Performance optimization: cached NEXT TextPainter
  late TextPainter _nextTextPainter;

  // Performance optimization: cached grid lines as Picture
  late ui.Picture _gridLinesPicture;
  double _lastGridLinesOffsetX = -1;
  double _lastGridLinesOffsetY = -1;
  double _lastGridLinesScale = -1;

  // Track milestone for celebration overlay
  int _previousMilestone = 0;

  bool isGameStarted = false;
  bool _isGameOverDetected = false;

  @override
  Future<void> onLoad() async {
    pauseEngine();
    sandWorld = SandWorld(cols: cols, rows: rows);
    _generateNextPiece();

    // Pre-allocate buffers for vertices (2 triangles per cell = 6 vertices, each with x,y)
    _vertices = Float32List(cols * rows * 12);
    _colors = Int32List(cols * rows * 6);

    // Initialize and layout NEXT TextPainter once
    _nextTextPainter = TextPainter(
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
    _nextTextPainter.layout();

    // Initialize milestone tracking
    _previousMilestone = MilestoneService.instance.getCurrentMilestone(ScoringService.instance.currentScore);

    _isLoaded = true;

    // Run initial update if resize happened already
    _updateVertexPositions();
  }

  void _generateNextPiece() {
    nextShape = _randomShape();
    // Get available colors based on current difficulty
    final currentScore = ScoringService.instance.currentScore;
    final availableColors = DifficultyService.instance.getAvailableColors(currentScore);
    nextColor = availableColors[Random().nextInt(availableColors.length)];
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    final topUIHeight = size.y * topUIRatio;
    final bottomUIHeight = size.y * bottomUIRatio;

    final playableHeight = size.y - topUIHeight - bottomUIHeight;
    final playableWidth = size.x - 2 * horizontalPadding;

    final cellWidth = playableWidth / cols;
    final cellHeight = playableHeight / rows;

    cellSize = cellWidth < cellHeight ? cellWidth : cellHeight;

    final gridWidth = cols * cellSize;
    final gridHeight = rows * cellSize;

    gridOffset = Offset(
      horizontalPadding + (playableWidth - gridWidth) / 2,
      topUIHeight + (playableHeight - gridHeight) / 2,
    );

    // Recompute static vertex positions if buffers are ready
    if (_isLoaded) {
      _updateVertexPositions();
      // Invalidate cached grid lines picture when size changes
      _lastGridLinesOffsetX = -1;
      _lastGridLinesOffsetY = -1;
      _lastGridLinesScale = -1;
    }
  }

  void _updateVertexPositions() {
    int vIdx = 0;
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final left = gridOffset.dx + x * cellSize;
        final top = gridOffset.dy + y * cellSize;
        final right = left + cellSize;
        final bottom = top + cellSize;

        // Triangle 1
        _vertices[vIdx++] = left;
        _vertices[vIdx++] = top;
        _vertices[vIdx++] = right;
        _vertices[vIdx++] = top;
        _vertices[vIdx++] = left;
        _vertices[vIdx++] = bottom;

        // Triangle 2
        _vertices[vIdx++] = right;
        _vertices[vIdx++] = top;
        _vertices[vIdx++] = right;
        _vertices[vIdx++] = bottom;
        _vertices[vIdx++] = left;
        _vertices[vIdx++] = bottom;
      }
    }
  }

  // =========================================================
  // INPUT
  // =========================================================

  @override
  void onTapDown(TapDownEvent event) {
    if (!sandWorld.isStable) return;
    if (sandWorld.isGameOver) return;

    final pos = event.localPosition;
    final gridX = ((pos.x - gridOffset.dx) / cellSize).floor();
    final gridY = ((pos.y - gridOffset.dy) / cellSize).floor();

    if (!sandWorld.isInside(gridX, gridY)) return;

    // Only generate next piece if placement was successful
    if (sandWorld.placeShape(nextShape, gridX, gridY, nextColor)) {
      _generateNextPiece();
    }
  }

  List<Point<int>> _randomShape() {
    final shapes = [
      [Point(-1, -1), Point(0, -1), Point(-1, 0), Point(0, 0)],
      [Point(-2, 0), Point(-1, 0), Point(0, 0), Point(1, 0)],
      [Point(-1, -1), Point(-1, 0), Point(-1, 1), Point(0, 1)],
    ];

    final baseShape = shapes[Random().nextInt(shapes.length)];
    int scale = cols ~/ 15;
    if (scale < 1) scale = 1;

    return _scaleShape(baseShape, scale);
  }

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

    // Pause game on game over
    if (sandWorld.isGameOver) {
      if (!_isGameOverDetected) {
        _isGameOverDetected = true;
        pauseEngine();
        overlays.add(GameConfig.gameOverOverlay);
      }
      return;
    }

    _accumulator += dt;

    while (_accumulator >= _step) {
      sandWorld.update(_step);
      _accumulator -= _step;
    }

    // Check for milestone changes
    final currentScore = ScoringService.instance.currentScore;
    final currentMilestone = MilestoneService.instance.getCurrentMilestone(currentScore);
    if (currentMilestone > _previousMilestone && isGameStarted) {
      overlays.add(GameConfig.celebrationOverlay);
      _previousMilestone = currentMilestone;
    }

    if (sandWorld.isStable && !_wasStableLastFrame) {
      // Merge adjacent same-color clusters to reduce fragmentation
      sandWorld.mergeAdjacentClusters();

      // Start a clear session to track combo bonuses
      ScoringService.instance.startClearSession();

      // Get available colors based on current difficulty
      final availableColors = DifficultyService.instance.getAvailableColors(currentScore);
      
      bool anyBridgesCleared = false;
      for (final c in availableColors) {
        if (sandWorld.clearSpanningBridge(c)) {
          anyBridgesCleared = true;
          // print('🚀 $c has formed a left-to-right bridge!');
        }
      }

      // Only end combo if no bridges were found
      // If bridges were found, the board will be unstable again and combo continues
      ScoringService.instance.endClearSessionIfNoBridges(anyBridgesCleared);
    }

    _wasStableLastFrame = sandWorld.isStable;
  }

  // =========================================================
  // RENDERING
  // =========================================================

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Update color buffer from world
    int cIdx = 0;
    final gridColorBuffer = sandWorld.gridColorBuffer;
    for (int i = 0; i < gridColorBuffer.length; i++) {
      final colorVal = gridColorBuffer[i];
      // 6 vertices per cell
      for (int j = 0; j < 6; j++) {
        _colors[cIdx++] = colorVal;
      }
    }

    final vertices = Vertices.raw(
      VertexMode.triangles,
      _vertices,
      colors: _colors,
    );

    canvas.drawVertices(vertices, BlendMode.src, Paint());

    _drawGridLines(canvas);
    _drawGameOverThreshold(canvas);
    _drawNextPiecePreview(canvas);
  }

  void _drawGameOverThreshold(Canvas canvas) {
    final thresholdY = gridOffset.dy + sandWorld.gameOverThresholdRow * cellSize;

    canvas.drawLine(
      Offset(gridOffset.dx, thresholdY),
      Offset(gridOffset.dx + cols * cellSize, thresholdY),
      Paint()
        ..color = Colors.red.withAlpha(204) // 80% opacity red
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawGridLines(Canvas canvas) {
    // Regenerate grid lines picture only if offset or scale changed
    if (_lastGridLinesOffsetX != gridOffset.dx ||
        _lastGridLinesOffsetY != gridOffset.dy ||
        _lastGridLinesScale != cellSize) {
      final recorder = ui.PictureRecorder();
      final recordingCanvas = Canvas(recorder);

      final paint = Paint()
        ..color = Colors.white12
        ..style = PaintingStyle.stroke;

      for (int x = 0; x <= cols; x++) {
        final dx = gridOffset.dx + x * cellSize;
        recordingCanvas.drawLine(
          Offset(dx, gridOffset.dy),
          Offset(dx, gridOffset.dy + rows * cellSize),
          paint,
        );
      }

      for (int y = 0; y <= rows; y++) {
        final dy = gridOffset.dy + y * cellSize;
        recordingCanvas.drawLine(
          Offset(gridOffset.dx, dy),
          Offset(gridOffset.dx + cols * cellSize, dy),
          paint,
        );
      }

      _gridLinesPicture = recorder.endRecording();
      _lastGridLinesOffsetX = gridOffset.dx;
      _lastGridLinesOffsetY = gridOffset.dy;
      _lastGridLinesScale = cellSize;
    }

    // Draw the cached grid lines picture
    canvas.drawPicture(_gridLinesPicture);
  }

  void _drawNextPiecePreview(Canvas canvas) {
    final previewX = (size.x - previewSize) / 2;
    final previewY = size.y - previewSize - 40;

    final bgRect = Rect.fromLTWH(previewX, previewY, previewSize, previewSize);
    canvas.drawRect(
      bgRect,
      Paint()
        ..color = Colors.black
            .withAlpha(153) // 0.6 * 255
        ..style = PaintingStyle.fill,
    );

    canvas.drawRect(
      bgRect,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Use cached NEXT TextPainter instead of creating new one every frame
    _nextTextPainter.paint(
      canvas,
      Offset(
        previewX + (previewSize - _nextTextPainter.width) / 2,
        previewY - 28,
      ),
    );

    if (nextShape.isEmpty) return;

    final previewCellSize = cellSize;

    final minX = nextShape.map((p) => p.x).reduce((a, b) => a < b ? a : b);
    final maxX = nextShape.map((p) => p.x).reduce((a, b) => a > b ? a : b);
    final minY = nextShape.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    final maxY = nextShape.map((p) => p.y).reduce((a, b) => a > b ? a : b);

    final shapeWidth = maxX - minX + 1;
    final shapeHeight = maxY - minY + 1;

    final totalShapeWidth = shapeWidth * previewCellSize;
    final totalShapeHeight = shapeHeight * previewCellSize;

    final offsetX =
        previewX + (previewSize - totalShapeWidth) / 2 - minX * previewCellSize;
    final offsetY =
        previewY +
        (previewSize - totalShapeHeight) / 2 -
        minY * previewCellSize;

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

  /// Resets game state for a new game. Clears the board and resets all game flags.
  void resetGameState() {
    sandWorld = SandWorld(cols: cols, rows: rows);
    _generateNextPiece();
    _isGameOverDetected = false;
    _previousMilestone = 0;
    _wasStableLastFrame = true;
    _accumulator = 0;
    _updateVertexPositions();
  }
}
