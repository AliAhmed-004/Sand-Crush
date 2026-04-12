import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sand_crush/services/scoring_service.dart';

/// -----------------------------
/// CELL MODEL
/// -----------------------------
class Cell {
  int x;
  int y;
  final Color color; // Display color (with variations)
  final int baseColorId; // Base color ID (0-5) for logic matching

  Cell(this.x, this.y, this.color, this.baseColorId);
}

/// -----------------------------
/// CLUSTER MODEL
/// -----------------------------
class Cluster {
  final int id;
  final List<Cell> cells;

  Cluster({required this.id, required this.cells});
}

/// -----------------------------
/// WORLD
/// -----------------------------
class SandWorld {
  final int cols;
  final int rows;

  /// Optimized grid for rendering: flat ABGR/ARGB color buffer (display colors with variations)
  final Uint32List gridColorBuffer;

  /// Base color ID buffer: tracks which base color (0-5) each cell belongs to
  /// Used for all color matching logic (clearing, bridges, etc.)
  final Uint8List baseColorIdBuffer;

  /// Active clusters in the world
  final Map<int, Cluster> clusters = {};

  /// Optimized lookup: index (y * cols + x) → clusterId
  /// Value of 0 means empty.
  final Int32List cellIdMap;

  // Singleton Random instance to avoid allocations in physics loop
  static final Random _random = Random();

  int _nextClusterId = 1;

  bool _isStable = true;
  bool get isStable => _isStable;

  bool _isGameOver = false;
  bool get isGameOver => _isGameOver;

  // Top 10% threshold: if sand reaches this row from the top, game is over
  late int _gameOverThresholdRow;
  int get gameOverThresholdRow => _gameOverThresholdRow;

  // Performance optimization: cached cluster list
  late List<Cluster> _cachedClusterList;
  int _lastKnownClusterCount = 0;

  // Dirty region tracking: stores cell indices that were occupied last frame
  // Used to efficiently clear only the cells that changed
  late Set<int> _previousFrameCellIndices;

  // Bridge detection optimization: cache which colors touch edges
  late Set<int> _leftEdgeColors;
  late Set<int> _rightEdgeColors;

  SandWorld({required this.cols, required this.rows})
    : gridColorBuffer = Uint32List(cols * rows),
      baseColorIdBuffer = Uint8List(cols * rows),
      cellIdMap = Int32List(cols * rows) {
    _isStable = true;
    _cachedClusterList = [];
    _previousFrameCellIndices = <int>{};
    _leftEdgeColors = <int>{};
    _rightEdgeColors = <int>{};
    _gameOverThresholdRow = (rows * 0.1).ceil(); // Top 10% of rows
  }

  // =========================================================
  // PRIVATE HELPERS
  // =========================================================

  /// Maps a base Color to its color ID (0-5)
  int _getColorId(Color color) {
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.purple,
    ];
    final colorVal = color.toARGB32();
    return colors.indexWhere((c) => c.toARGB32() == colorVal);
  }

  /// Attempts to match an ARGB value to a base color ID by finding the closest match
  /// Used when reconstructing from saved games that might have color variations
  int _getColorIdFromValue(int colorValue) {
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.purple,
    ];

    // If exact match, use it
    for (int i = 0; i < colors.length; i++) {
      if (colors[i].toARGB32() == colorValue) return i;
    }

    // Otherwise find closest by RGB distance
    // Extract RGB components from ARGB value
    final targetR = (colorValue >> 16) & 0xFF;
    final targetG = (colorValue >> 8) & 0xFF;
    final targetB = colorValue & 0xFF;

    int closestIdx = 0;
    double closestDistance = double.maxFinite;

    for (int i = 0; i < colors.length; i++) {
      final c = colors[i];
      final cVal = c.toARGB32();
      final cR = (cVal >> 16) & 0xFF;
      final cG = (cVal >> 8) & 0xFF;
      final cB = cVal & 0xFF;

      final dr = (cR - targetR).toDouble();
      final dg = (cG - targetG).toDouble();
      final db = (cB - targetB).toDouble();
      final distance = dr * dr + dg * dg + db * db;

      if (distance < closestDistance) {
        closestDistance = distance;
        closestIdx = i;
      }
    }

    return closestIdx;
  }

  /// Varies the color slightly to add visual depth. Creates subtle shade variations
  /// of the same hue so cells have slightly different tones.
  Color _varyColor(Color baseColor) {
    final hsv = HSVColor.fromColor(baseColor);
    
    // Vary hue slightly (±2 degrees for subtle variation)
    final hueVariation = (_random.nextDouble() - 0.5) * 4;
    final newHue = (hsv.hue + hueVariation) % 360;
    
    // Vary saturation slightly (±5% for subtle depth)
    final satVariation = (_random.nextDouble() - 0.5) * 0.1;
    final newSaturation = (hsv.saturation + satVariation).clamp(0.0, 1.0);
    
    // Vary value (brightness) slightly (±8% for tonal variation)
    final valueVariation = (_random.nextDouble() - 0.5) * 0.16;
    final newValue = (hsv.value + valueVariation).clamp(0.0, 1.0);
    
    return HSVColor.fromAHSV(
      hsv.alpha,
      newHue,
      newSaturation,
      newValue,
    ).toColor();
  }

  // =========================================================
  // PUBLIC API
  // =========================================================

  /// Checks if a shape can be placed at the given position without overlapping.
  /// Position will be adjusted to fit within bounds. Returns true if all cells are empty.
  bool canPlace(List<Point<int>> offsets, int originX, int originY) {
    if (offsets.isEmpty) return false;

    int minX = 0, maxX = 0, minY = 0, maxY = 0;
    for (final o in offsets) {
      if (o.x < minX) minX = o.x;
      if (o.x > maxX) maxX = o.x;
      if (o.y < minY) minY = o.y;
      if (o.y > maxY) maxY = o.y;
    }

    final adjustedX = originX.clamp(-minX, cols - 1 - maxX);
    final adjustedY = originY.clamp(-minY, rows - 1 - maxY);

    // Check if all cells are empty
    for (final o in offsets) {
      final x = adjustedX + o.x;
      final y = adjustedY + o.y;

      if (!isInside(x, y)) return false;
      if (cellIdMap[y * cols + x] != 0) return false; // Cell already occupied
    }

    return true;
  }

  /// Checks if a single cell can be placed at the given position.
  bool canPlaceCell(int x, int y) {
    if (!isInside(x, y)) return false;
    return cellIdMap[y * cols + x] == 0;
  }

  void placeCell(int x, int y, Color color) {
    if (!canPlaceCell(x, y)) return;
    final colorId = _getColorId(color);
    _createCluster([Cell(x, y, _varyColor(color), colorId)]);
  }

  /// Attempts to place a shape. Returns true if successful, false otherwise.
  bool placeShape(
    List<Point<int>> offsets,
    int originX,
    int originY,
    Color color,
  ) {
    if (!canPlace(offsets, originX, originY)) return false;

    // add placement points for each cell placed
    ScoringService.instance.addBlockPlacementPoints();

    // Adjust position to fit within bounds
    int minX = 0, maxX = 0, minY = 0, maxY = 0;
    for (final o in offsets) {
      if (o.x < minX) minX = o.x;
      if (o.x > maxX) maxX = o.x;
      if (o.y < minY) minY = o.y;
      if (o.y > maxY) maxY = o.y;
    }

    // Clamp origin to ensure shape fits within bounds
    final adjustedX = originX.clamp(-minX, cols - 1 - maxX);
    final adjustedY = originY.clamp(-minY, rows - 1 - maxY);

    // Create cells for the shape with color variations
    final colorId = _getColorId(color);
    final cells = offsets.map((o) {
      return Cell(adjustedX + o.x, adjustedY + o.y, _varyColor(color), colorId);
    }).toList();

    _createCluster(cells);
    return true;
  }

  void update(double dt) {
    _applyClusterPhysics();
    _syncGridFromClusters();
  }

  /// Merges adjacent same-color 1-cell clusters to reduce fragmentation.
  /// Call this after the board stabilizes (isStable == true).
  void mergeAdjacentClusters() {
    if (!_isStable || clusters.isEmpty) return;

    final clustersByColorId = <int, List<Cluster>>{};
    for (final cluster in clusters.values) {
      if (cluster.cells.length != 1) continue;
      final colorId = cluster.cells.first.baseColorId;
      clustersByColorId.putIfAbsent(colorId, () => []).add(cluster);
    }

    for (final colorClusters in clustersByColorId.values) {
      final processed = <int>{};

      for (final cluster in colorClusters) {
        if (processed.contains(cluster.id)) continue;

        final cell = cluster.cells.first;
        final toMerge = [cluster];
        processed.add(cluster.id);

        final adjacent = [
          (cell.x - 1, cell.y),
          (cell.x + 1, cell.y),
          (cell.x, cell.y - 1),
          (cell.x, cell.y + 1),
        ];

        for (final (nx, ny) in adjacent) {
          if (!isInside(nx, ny)) continue;
          final adjClusterId = cellIdMap[ny * cols + nx];
          if (adjClusterId == 0 || processed.contains(adjClusterId)) continue;
          final adjCluster = clusters[adjClusterId];
          if (adjCluster == null ||
              adjCluster.cells.length != 1 ||
              adjCluster.cells.first.baseColorId !=
                  cluster.cells.first.baseColorId) {
            continue;
          }
          toMerge.add(adjCluster);
          processed.add(adjClusterId);
        }

        if (toMerge.length > 1) {
          final mergedCells = <Cell>[];
          for (final c in toMerge) {
            mergedCells.addAll(c.cells);
            clusters.remove(c.id);
            for (final cell in c.cells) {
              cellIdMap[cell.y * cols + cell.x] = 0;
            }
          }

          final newClusterId = _nextClusterId++;
          final mergedCluster = Cluster(id: newClusterId, cells: mergedCells);
          clusters[newClusterId] = mergedCluster;
          for (final cell in mergedCells) {
            cellIdMap[cell.y * cols + cell.x] = newClusterId;
          }
        }
      }
    }
  }

  bool isInside(int x, int y) {
    return x >= 0 && x < cols && y >= 0 && y < rows;
  }

  /// Resets the game-over state. Called when starting a new game.
  void resetGameOverState() {
    _isGameOver = false;
  }

  // =========================================================
  // CLUSTER CREATION
  // =========================================================

  void _createCluster(List<Cell> cells) {
    final id = _nextClusterId++;
    final cluster = Cluster(id: id, cells: cells);
    clusters[id] = cluster;

    for (final c in cells) {
      if (!isInside(c.x, c.y)) continue;
      cellIdMap[c.y * cols + c.x] = id;
    }
  }

  // =========================================================
  // PHYSICS (CLUSTER-BASED GRAVITY)
  // =========================================================

  void _applyClusterPhysics() {
    // Cache cluster list, rebuild only when cluster count changes
    if (clusters.length != _lastKnownClusterCount) {
      _cachedClusterList = clusters.values.toList();
      _lastKnownClusterCount = clusters.length;
    }
    final clusterList = _cachedClusterList;
    bool anyMovement = false;

    for (final cluster in clusterList) {
      if (!clusters.containsKey(cluster.id)) continue;

      if (_tryMoveCluster(cluster, 0, 1)) {
        anyMovement = true;
        continue;
      }

      final leftFirst = _random.nextBool();
      bool moved = false;

      if (leftFirst) {
        if (_isClusterSupportedAfterMove(cluster, -1, 1) &&
            _tryMoveCluster(cluster, -1, 1)) {
          moved = true;
        } else if (_isClusterSupportedAfterMove(cluster, 1, 1) &&
            _tryMoveCluster(cluster, 1, 1)) {
          moved = true;
        }
      } else {
        if (_isClusterSupportedAfterMove(cluster, 1, 1) &&
            _tryMoveCluster(cluster, 1, 1)) {
          moved = true;
        } else if (_isClusterSupportedAfterMove(cluster, -1, 1) &&
            _tryMoveCluster(cluster, -1, 1)) {
          moved = true;
        }
      }

      if (moved) {
        anyMovement = true;
        continue;
      }

      if (cluster.cells.length > 1) {
        _breakApartCluster(cluster);
        continue;
      }
    }

    _isStable = !anyMovement;

    // Check for game over condition when board stabilizes
    if (_isStable) {
      _checkGameOverCondition();
    }
  }

  /// Checks if sand has reached the top threshold (top 10% of grid).
  /// If so, marks the game as over.
  void _checkGameOverCondition() {
    if (_isGameOver) return; // Already game over, no need to check again

    for (int y = 0; y < _gameOverThresholdRow; y++) {
      for (int x = 0; x < cols; x++) {
        if (gridColorBuffer[y * cols + x] != 0) {
          _isGameOver = true;
          return;
        }
      }
    }
  }

  void _breakApartCluster(Cluster cluster) {
    if (cluster.cells.isEmpty) {
      clusters.remove(cluster.id);
      return;
    }

    clusters.remove(cluster.id);

    for (final cell in cluster.cells) {
      cellIdMap[cell.y * cols + cell.x] = 0;
    }

    for (final cell in cluster.cells) {
      if (!isInside(cell.x, cell.y)) continue;
      _createCluster([Cell(cell.x, cell.y, cell.color, cell.baseColorId)]);
    }
  }

  bool _tryMoveCluster(Cluster cluster, int dx, int dy) {
    for (final cell in cluster.cells) {
      final nx = cell.x + dx;
      final ny = cell.y + dy;

      if (!isInside(nx, ny)) return false;

      final existingId = cellIdMap[ny * cols + nx];
      if (existingId != 0 && existingId != cluster.id) {
        return false;
      }
    }

    for (final cell in cluster.cells) {
      cellIdMap[cell.y * cols + cell.x] = 0;
    }

    for (final cell in cluster.cells) {
      cell.x += dx;
      cell.y += dy;
    }

    for (final cell in cluster.cells) {
      cellIdMap[cell.y * cols + cell.x] = cluster.id;
    }

    return true;
  }

  // =========================================================
  // GRID SYNC (With Dirty Region Tracking)
  // =========================================================

  void _syncGridFromClusters() {
    // Cell-level dirty tracking: clear only cells that were occupied in previous frame
    // This is much more efficient than clearing the entire 8000-cell buffer every frame
    for (final cellIndex in _previousFrameCellIndices) {
      gridColorBuffer[cellIndex] = 0;
      baseColorIdBuffer[cellIndex] = 0;
    }

    // Collect current frame cell indices and edge colors for bridge detection optimization
    final currentFrameCellIndices = <int>{};
    _leftEdgeColors.clear();
    _rightEdgeColors.clear();

    // Update grid with current cluster cells
    for (final cluster in clusters.values) {
      for (final cell in cluster.cells) {
        if (isInside(cell.x, cell.y)) {
          final cellIndex = cell.y * cols + cell.x;
          final colorVal = cell.color.toARGB32();
          gridColorBuffer[cellIndex] = colorVal;
          baseColorIdBuffer[cellIndex] = cell.baseColorId;
          currentFrameCellIndices.add(cellIndex);

          // Track which color IDs touch the edges for bridge detection optimization
          if (cell.x == 0) {
            _leftEdgeColors.add(cell.baseColorId);
          }
          if (cell.x == cols - 1) {
            _rightEdgeColors.add(cell.baseColorId);
          }
        }
      }
    }

    // Swap tracking set for next frame
    _previousFrameCellIndices = currentFrameCellIndices;
  }

  bool doesColorSpanLeftToRight(Color color) {
    if (!_isStable) return false;

    final colorId = _getColorId(color);
    if (colorId == -1) return false; // Color not found
    
    bool touchesLeft = false;
    bool touchesRight = false;
    for (int y = 0; y < rows; y++) {
      if (baseColorIdBuffer[y * cols] == colorId) touchesLeft = true;
      if (baseColorIdBuffer[y * cols + (cols - 1)] == colorId) {
        touchesRight = true;
      }
    }
    if (!touchesLeft || !touchesRight) return false;

    final visited = Uint8List(rows * cols);
    final queue = <int>[];

    for (int y = 0; y < rows; y++) {
      final idx = y * cols;
      if (baseColorIdBuffer[idx] == colorId) {
        visited[idx] = 1;
        queue.add(idx);
      }
    }

    final neighbors = [
      1,
      -1,
      cols,
      -cols,
      cols + 1,
      cols - 1,
      -cols + 1,
      -cols - 1,
    ];

    int head = 0;
    while (head < queue.length) {
      final currIdx = queue[head++];
      final cx = currIdx % cols;

      if (cx == cols - 1) return true;

      for (final offset in neighbors) {
        final nextIdx = currIdx + offset;
        if (nextIdx < 0 || nextIdx >= rows * cols) continue;

        final nx = nextIdx % cols;
        if ((cx == 0 && (nx == cols - 1)) || (cx == cols - 1 && (nx == 0))) {
          continue;
        }

        if (visited[nextIdx] == 0 && baseColorIdBuffer[nextIdx] == colorId) {
          visited[nextIdx] = 1;
          queue.add(nextIdx);
        }
      }
    }

    return false;
  }

  bool clearSpanningBridge(Color color) {
    if (!_isStable) return false;

    final colorId = _getColorId(color);
    if (colorId == -1) return false; // Color not found
    
    // Quick reject: use cached edge color info instead of scanning edges
    // This saves O(rows * 2) operations per color check
    if (!_leftEdgeColors.contains(colorId) || !_rightEdgeColors.contains(colorId)) {
      return false;
    }

    // BFS to find all connected cells of the color starting from the left edge
    final visited = Uint8List(rows * cols);
    final queue = <int>[];
    final toClear = <int>[];

    // Start BFS from all cells of the target color on the left edge
    for (int y = 0; y < rows; y++) {
      final idx = y * cols;
      if (baseColorIdBuffer[idx] == colorId) {
        visited[idx] = 1;
        queue.add(idx);
        toClear.add(idx);
      }
    }

    // Track if we reach the right edge during BFS
    bool reachesRight = false;

    // 8-directional neighbors to ensure we clear diagonally connected bridges as well
    final neighbors = [
      1,
      -1,
      cols,
      -cols,
      cols + 1,
      cols - 1,
      -cols + 1,
      -cols - 1,
    ];

    int head = 0;

    // Standard BFS loop
    while (head < queue.length) {
      final currIdx = queue[head++];
      final cx = currIdx % cols;
      if (cx == cols - 1) reachesRight = true;

      // Explore all 8 neighbors
      for (final offset in neighbors) {
        final nextIdx = currIdx + offset;
        if (nextIdx < 0 || nextIdx >= rows * cols) continue;

        final nx = nextIdx % cols;
        if ((cx == 0 && (nx == cols - 1)) || (cx == cols - 1 && (nx == 0))) {
          continue;
        }

        if (visited[nextIdx] == 0 && baseColorIdBuffer[nextIdx] == colorId) {
          visited[nextIdx] = 1;
          queue.add(nextIdx);
          toClear.add(nextIdx);
        }
      }
    }

    if (!reachesRight) return false;

    // Award points for clearing the bridge
    ScoringService.instance.addSandClearPoints(1, toClear.length);

    // Clear the identified bridge cells
    for (final idx in toClear) {
      gridColorBuffer[idx] = 0;
      cellIdMap[idx] = 0;
    }

    _cleanupStaleClusters();
    return true;
  }

  /// After clearing cells directly in the grid, some clusters may have lost all their cells or become invalid.
  /// This method scans through existing clusters and removes any that no longer have valid cells in the grid.
  void _cleanupStaleClusters() {
    final idsToRemove = <int>[];
    for (final entry in clusters.entries) {
      final cluster = entry.value;
      bool stillValid = false;
      for (final cell in cluster.cells) {
        if (cellIdMap[cell.y * cols + cell.x] == entry.key) {
          stillValid = true;
          break;
        }
      }
      if (!stillValid) idsToRemove.add(entry.key);
    }
    for (final id in idsToRemove) {
      clusters.remove(id);
    }
  }

  bool _isClusterSupportedAfterMove(Cluster cluster, int dx, int dy) {
    for (final cell in cluster.cells) {
      final nx = cell.x + dx;
      final ny = cell.y + dy;

      if (!isInside(nx, ny)) return false;

      final belowX = nx;
      final belowY = ny + 1;

      if (belowY >= rows) continue;

      final belowIdx = belowY * cols + belowX;
      final occupantId = cellIdMap[belowIdx];

      if (occupantId != 0 && occupantId != cluster.id) continue;

      return false;
    }
    return true;
  }

  // Rebuild cluster from saved game
  void rebuildClusters(SandWorld world) {
    // Clear dirty tracking and edge colors to get fresh state after rebuild
    world._previousFrameCellIndices.clear();
    world._leftEdgeColors.clear();
    world._rightEdgeColors.clear();
    
    final visited = <int>{};
    final cols = world.cols;
    final rows = world.rows;

    for (int i = 0; i < world.gridColorBuffer.length; i++) {
      if (world.gridColorBuffer[i] == 0 || visited.contains(i)) continue;

      final color = world.gridColorBuffer[i];
      // Use saved baseColorId if available, otherwise try to reconstruct
      final colorId = world.baseColorIdBuffer[i] != 0
          ? world.baseColorIdBuffer[i]
          : world._getColorIdFromValue(color);
      
      final queue = [i];
      final cells = <Cell>[];

      visited.add(i);

      while (queue.isNotEmpty) {
        final idx = queue.removeLast();
        final x = idx % cols;
        final y = idx ~/ cols;

        cells.add(Cell(x, y, Color(color), colorId));

        final neighbors = [idx + 1, idx - 1, idx + cols, idx - cols];

        for (final n in neighbors) {
          if (n < 0 || n >= cols * rows) continue;
          if (visited.contains(n)) continue;
          if (world.gridColorBuffer[n] != color) continue;

          visited.add(n);
          queue.add(n);
        }
      }

      world._createCluster(cells);
    }
  }
}
