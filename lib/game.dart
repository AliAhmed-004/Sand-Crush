import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:sand_crush/config/game_config.dart';
import 'package:sand_crush/models/game_state_dto.dart';
import 'package:sand_crush/services/difficulty_service.dart';
import 'package:sand_crush/services/high_score_service.dart';
import 'package:sand_crush/services/milestone_service.dart';
import 'package:sand_crush/services/save_game_service.dart';
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

  // Singleton Random instance to avoid allocations
  static final Random _random = Random();

  // Batched rendering buffers
  late Float32List _vertices;
  late Int32List _colors;

  // Fixed timestep accumulator
  double _accumulator = 0;
  static const double _step = 1 / 60;

  // Track stability to trigger bridge checks only when the board transitions from unstable to stable
  bool _wasStableLastFrame = true;

  // Debounced save frequency: save game state only after every N successful placements
  static const int _saveInterval = 5;
  int _placementsSinceLastSave = 0;

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

  // Clearing animation tracking
  static const double _clearFlashDuration = 0.05; // 50ms glow flash
  static const double _clearWaveDuration = 0.3; // 300ms wave effect
  double _clearingElapsedTime = 0;
  final Map<int, double> _clearingCellAnimations = {}; // cell index → wave start time
  List<int> _cellsToClears = []; // indices of cells that need to clear

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
    nextColor = availableColors[_random.nextInt(availableColors.length)];
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
      
      // Debounced save: only save every N placements
      _placementsSinceLastSave++;
      if (_placementsSinceLastSave >= _saveInterval) {
        final gameStateDTO = GameStateDTO(
          cols: sandWorld.cols,
          rows: sandWorld.rows,
          grid: sandWorld.gridColorBuffer.toList(),
          baseColorIds: sandWorld.baseColorIdBuffer.toList(),
        );
        SaveGameService.instance.saveGame(gameStateDTO, ScoringService.instance.currentScore);
        _placementsSinceLastSave = 0;
      }
    }
  }

  List<Point<int>> _randomShape() {
    final shapes = [
      [Point(-1, -1), Point(0, -1), Point(-1, 0), Point(0, 0)],
      [Point(-2, 0), Point(-1, 0), Point(0, 0), Point(1, 0)],
      [Point(-1, -1), Point(-1, 0), Point(-1, 1), Point(0, 1)],
    ];

    final baseShape = shapes[_random.nextInt(shapes.length)];
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

    // Update clearing animation if in progress
    if (_cellsToClears.isNotEmpty) {
      _clearingElapsedTime += dt;
      
      // After animation completes, finalize the clearing
      if (_clearingElapsedTime >= _clearFlashDuration + _clearWaveDuration) {
        sandWorld.finalizeClear(_cellsToClears);
        _cellsToClears.clear();
        _clearingElapsedTime = 0;
        _clearingCellAnimations.clear();
      }
      
      // Skip physics during clearing animation
      _wasStableLastFrame = sandWorld.isStable;
      return;
    }

    // Pause game on game over
    if (sandWorld.isGameOver) {
      if (!_isGameOverDetected) {
        _isGameOverDetected = true;
        // Save high score if current score is higher
        HighScoreService.instance.saveHighScoreIfHigher(
          ScoringService.instance.currentScore,
        );
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
          // Start clearing animation if cells were cleared
          if (sandWorld.lastClearedIndices.isNotEmpty) {
            _startClearingAnimation(sandWorld.lastClearedIndices);
          }
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
      
      // Apply clearing animation opacity if this cell is being cleared
      int animatedColor = colorVal;
      if (_cellsToClears.contains(i)) {
        animatedColor = _getAnimatedCellColor(i, colorVal);
      }
      
      // 6 vertices per cell
      for (int j = 0; j < 6; j++) {
        _colors[cIdx++] = animatedColor;
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

  void _startClearingAnimation(List<int> cellIndices) {
    _cellsToClears = List.from(cellIndices);
    _clearingElapsedTime = 0;
    _clearingCellAnimations.clear();
    
    // Pre-calculate when each cell's wave will reach it (based on x position)
    for (final idx in cellIndices) {
      final x = idx % cols;
      // Wave travels left to right, starting after flash duration
      final cellDelayFraction = x / cols; // 0 at left, 1 at right
      final waveStartTime = _clearFlashDuration + (cellDelayFraction * _clearWaveDuration);
      _clearingCellAnimations[idx] = waveStartTime;
    }
  }

  int _getAnimatedCellColor(int cellIndex, int originalColor) {
    // Extract ARGB components
    final alpha = (originalColor >> 24) & 0xFF;
    final red = (originalColor >> 16) & 0xFF;
    final green = (originalColor >> 8) & 0xFF;
    final blue = originalColor & 0xFF;

    // Glow flash phase (0 to _clearFlashDuration)
    if (_clearingElapsedTime < _clearFlashDuration) {
      // Brighten all cells during flash
      final flashProgress = _clearingElapsedTime / _clearFlashDuration;
      final brightnessFactor = 1.0 + (0.4 * flashProgress); // Brighten by up to 40%
      
      final newRed = ((red * brightnessFactor).clamp(0, 255)).toInt();
      final newGreen = ((green * brightnessFactor).clamp(0, 255)).toInt();
      final newBlue = ((blue * brightnessFactor).clamp(0, 255)).toInt();
      
      return (alpha << 24) | (newRed << 16) | (newGreen << 8) | newBlue;
    }

    // Wave fade phase
    final waveStartTime = _clearingCellAnimations[cellIndex] ?? _clearFlashDuration;
    final timeSinceWaveStart = _clearingElapsedTime - waveStartTime;

    // Cell hasn't been reached by wave yet - keep original color
    if (timeSinceWaveStart < 0) {
      return originalColor;
    }

    // Cell is being cleared by wave - fade to transparent
    final cellFadeProgress = (timeSinceWaveStart / _clearWaveDuration).clamp(0.0, 1.0);
    
    // Fade opacity from 255 to 0
    final newAlpha = (alpha * (1.0 - cellFadeProgress)).toInt();
    
    return (newAlpha << 24) | (red << 16) | (green << 8) | blue;
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

    // Draw grid border
    final borderRect = Rect.fromLTWH(
      gridOffset.dx,
      gridOffset.dy,
      cols * cellSize,
      rows * cellSize,
    );

    canvas.drawRect(
      borderRect,
      Paint()
        ..color = Colors.white38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // Optional: inner shadow effect with a slightly darker line
    canvas.drawRect(
      borderRect.inflate(-2),
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
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
    _placementsSinceLastSave = 0;
    _updateVertexPositions();
  }

  /// Loads a saved game state and rebuilds the world from the saved grid.
  void loadSavedGame() {
    final saveService = SaveGameService.instance;
    final savedData = saveService.loadGame();

    if (savedData == null) {
      return;
    }

    try {
      // Restore the grid data
      final cols = savedData['cols'] as int;
      final rows = savedData['rows'] as int;
      final gridList = savedData['grid'] as List;
      final gridData = List<int>.from(gridList);
      final baseColorIdsList = savedData['baseColorIds'] as List?;
      final baseColorIds = baseColorIdsList != null ? List<int>.from(baseColorIdsList) : null;
      final score = savedData['score'] as int;

      // Reset world and restore grid
      sandWorld = SandWorld(cols: cols, rows: rows);
      sandWorld.gridColorBuffer.setAll(0, gridData);
      
      // Restore base color IDs if available
      if (baseColorIds != null && baseColorIds.length == cols * rows) {
        sandWorld.baseColorIdBuffer.setAll(0, baseColorIds);
      }

      // Rebuild clusters from the restored grid
      sandWorld.rebuildClusters(sandWorld);

      // Restore score
      ScoringService.instance.setScore(score);

      // Generate next piece and reset flags
      _generateNextPiece();
      _isGameOverDetected = false;
      _previousMilestone = 0;
      _wasStableLastFrame = true;
      _accumulator = 0;
      _placementsSinceLastSave = 0;
      _updateVertexPositions();
    } catch (e) {
      // Silently fail if load is corrupted
    }
  }
}
