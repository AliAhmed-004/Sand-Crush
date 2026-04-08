import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

/// -----------------------------
/// CELL MODEL
/// -----------------------------
class Cell {
  int x;
  int y;
  final Color color;

  Cell(this.x, this.y, this.color);
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

  /// Optimized grid for rendering: flat ABGR/ARGB color buffer
  final Uint32List gridColorBuffer;

  /// Active clusters in the world
  final Map<int, Cluster> clusters = {};

  /// Optimized lookup: index (y * cols + x) → clusterId
  /// Value of 0 means empty.
  final Int32List cellIdMap;

  int _nextClusterId = 1;

  bool _isStable = true;
  bool get isStable => _isStable;

  SandWorld({required this.cols, required this.rows})
    : gridColorBuffer = Uint32List(cols * rows),
      cellIdMap = Int32List(cols * rows) {
    _isStable = true;
  }

  // =========================================================
  // PUBLIC API
  // =========================================================

  void placeCell(int x, int y, Color color) {
    _createCluster([Cell(x, y, color)]);
  }

  void placeShape(
    List<Point<int>> offsets,
    int originX,
    int originY,
    Color color,
  ) {
    if (offsets.isEmpty) return;

    int minX = 0, maxX = 0, minY = 0, maxY = 0;
    for (final o in offsets) {
      if (o.x < minX) minX = o.x;
      if (o.x > maxX) maxX = o.x;
      if (o.y < minY) minY = o.y;
      if (o.y > maxY) maxY = o.y;
    }

    final adjustedX = originX.clamp(-minX, cols - 1 - maxX);
    final adjustedY = originY.clamp(-minY, rows - 1 - maxY);

    final cells = offsets.map((o) {
      return Cell(adjustedX + o.x, adjustedY + o.y, color);
    }).toList();

    _createCluster(cells);
  }

  void update(double dt) {
    _applyClusterPhysics();
    _syncGridFromClusters();
  }

  bool isInside(int x, int y) {
    return x >= 0 && x < cols && y >= 0 && y < rows;
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
    final clusterList = clusters.values.toList();
    bool anyMovement = false;

    for (final cluster in clusterList) {
      if (!clusters.containsKey(cluster.id)) continue;

      if (_tryMoveCluster(cluster, 0, 1)) {
        anyMovement = true;
        continue;
      }

      final leftFirst = Random().nextBool();
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
      _createCluster([Cell(cell.x, cell.y, cell.color)]);
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
  // GRID SYNC
  // =========================================================

  void _syncGridFromClusters() {
    gridColorBuffer.fillRange(0, gridColorBuffer.length, 0);

    for (final cluster in clusters.values) {
      for (final cell in cluster.cells) {
        if (isInside(cell.x, cell.y)) {
          gridColorBuffer[cell.y * cols + cell.x] = cell.color.value;
        }
      }
    }
  }

  bool doesColorSpanLeftToRight(Color color) {
    if (!_isStable) return false;

    final colorVal = color.value;
    bool touchesLeft = false;
    bool touchesRight = false;
    for (int y = 0; y < rows; y++) {
      if (gridColorBuffer[y * cols] == colorVal) touchesLeft = true;
      if (gridColorBuffer[y * cols + (cols - 1)] == colorVal)
        touchesRight = true;
    }
    if (!touchesLeft || !touchesRight) return false;

    final visited = Uint8List(rows * cols);
    final queue = <int>[];

    for (int y = 0; y < rows; y++) {
      final idx = y * cols;
      if (gridColorBuffer[idx] == colorVal) {
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
        if ((cx == 0 && (nx == cols - 1)) || (cx == cols - 1 && (nx == 0)))
          continue;

        if (visited[nextIdx] == 0 && gridColorBuffer[nextIdx] == colorVal) {
          visited[nextIdx] = 1;
          queue.add(nextIdx);
        }
      }
    }

    return false;
  }

  bool clearSpanningBridge(Color color) {
    if (!_isStable) return false;

    final colorVal = color.value;
    bool touchesLeft = false;
    bool touchesRight = false;
    for (int y = 0; y < rows; y++) {
      if (gridColorBuffer[y * cols] == colorVal) touchesLeft = true;
      if (gridColorBuffer[y * cols + (cols - 1)] == colorVal)
        touchesRight = true;
    }
    if (!touchesLeft || !touchesRight) return false;

    final visited = Uint8List(rows * cols);
    final queue = <int>[];
    final toClear = <int>[];

    for (int y = 0; y < rows; y++) {
      final idx = y * cols;
      if (gridColorBuffer[idx] == colorVal) {
        visited[idx] = 1;
        queue.add(idx);
        toClear.add(idx);
      }
    }

    bool reachesRight = false;
    final neighbors = [1, -1, cols, -cols];

    int head = 0;
    while (head < queue.length) {
      final currIdx = queue[head++];
      final cx = currIdx % cols;
      if (cx == cols - 1) reachesRight = true;

      for (final offset in neighbors) {
        final nextIdx = currIdx + offset;
        if (nextIdx < 0 || nextIdx >= rows * cols) continue;

        final nx = nextIdx % cols;
        if ((cx == 0 && (nx == cols - 1)) || (cx == cols - 1 && (nx == 0)))
          continue;

        if (visited[nextIdx] == 0 && gridColorBuffer[nextIdx] == colorVal) {
          visited[nextIdx] = 1;
          queue.add(nextIdx);
          toClear.add(nextIdx);
        }
      }
    }

    if (!reachesRight) return false;

    for (final idx in toClear) {
      gridColorBuffer[idx] = 0;
      cellIdMap[idx] = 0;
    }

    _cleanupStaleClusters();
    return true;
  }

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
}
