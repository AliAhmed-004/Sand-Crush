import 'dart:math';
import 'dart:ui';

/// -----------------------------
/// CELL MODEL
/// -----------------------------
class Cell {
  int x;
  int y;
  final Color color; // ← NEW: every grain remembers its color

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

  /// Grid is now ONLY for rendering lookup (not physics truth)
  late List<List<Color?>> grid;

  /// Active clusters in the world
  final Map<int, Cluster> clusters = {};

  /// Fast lookup: (x,y) → clusterId
  final Map<Point<int>, int> cellMap = {};

  int _nextClusterId = 1;

  bool _isStable = true;
  bool get isStable => _isStable;

  SandWorld({required this.cols, required this.rows}) {
    grid = List.generate(rows, (_) => List.generate(cols, (_) => null));
    _isStable = true;
  }

  // =========================================================
  // PUBLIC API
  // =========================================================

  /// Spawn a single cell as its own cluster (old behavior compatibility)
  void placeCell(int x, int y, Color color) {
    _createCluster([Cell(x, y, color)]);
  }

  /// Spawn a Tetris-like shape, automatically adjusted to fit entirely inside the grid.
  /// Spawn a Tetris-like shape centered on the tap position.
  /// The entire shape is guaranteed to fit inside the grid.
  void placeShape(
    List<Point<int>> offsets,
    int originX,
    int originY,
    Color color,
  ) {
    if (offsets.isEmpty) return;

    // Compute bounding box relative to the center (0,0)
    final minX = offsets.map((o) => o.x).reduce((a, b) => a < b ? a : b);
    final maxX = offsets.map((o) => o.x).reduce((a, b) => a > b ? a : b);
    final minY = offsets.map((o) => o.y).reduce((a, b) => a < b ? a : b);
    final maxY = offsets.map((o) => o.y).reduce((a, b) => a > b ? a : b);

    // Clamp the center point so the whole shape stays inside the grid
    final adjustedX = originX.clamp(-minX, cols - 1 - maxX);
    final adjustedY = originY.clamp(-minY, rows - 1 - maxY);

    // Create cells with the adjusted center
    final cells = offsets.map((o) {
      return Cell(adjustedX + o.x, adjustedY + o.y, color);
    }).toList();

    _createCluster(cells);
  }

  /// Update simulation
  void update(double dt) {
    _applyClusterPhysics();
    _syncGridFromClusters();
  }

  /// Bounds check
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

      cellMap[Point(c.x, c.y)] = id;
    }
  }

  // =========================================================
  // PHYSICS (CLUSTER-BASED GRAVITY)
  // =========================================================

  void _applyClusterPhysics() {
    final clusterList = clusters.values.toList();

    bool anyMovement = false; // ← NEW: track real movement

    for (final cluster in clusterList) {
      if (!clusters.containsKey(cluster.id)) continue;

      // Try straight down first
      bool moved = _tryMoveCluster(cluster, 0, 1);
      if (moved) {
        anyMovement = true;
        continue; // already moved, skip other directions
      }

      // Then down-left
      moved = _tryMoveCluster(cluster, -1, 1);
      if (moved) {
        anyMovement = true;
        continue;
      }

      // Then down-right
      moved = _tryMoveCluster(cluster, 1, 1);
      if (moved) {
        anyMovement = true;
        continue;
      }

      // Nothing could move → break apart (this does NOT count as movement)
      _breakApartCluster(cluster);
    }

    _isStable = !anyMovement; // ← NEW: stable = nothing actually moved
  }

  void _breakApartCluster(Cluster cluster) {
    // Remove the cluster from active simulation
    clusters.remove(cluster.id);

    // Create a single-cell cluster for each cell to settle independently
    for (final cell in cluster.cells) {
      if (!isInside(cell.x, cell.y)) continue;

      // Create a new cluster with just this cell
      _createCluster([Cell(cell.x, cell.y, cell.color)]);
    }
  }

  bool _tryMoveCluster(Cluster cluster, int dx, int dy) {
    // 1. Check collision
    for (final cell in cluster.cells) {
      final nx = cell.x + dx;
      final ny = cell.y + dy;

      if (!isInside(nx, ny)) return false;

      final existing = cellMap[Point(nx, ny)];

      if (existing != null && existing != cluster.id) {
        return false;
      }
    }

    // 2. Remove old positions
    for (final cell in cluster.cells) {
      cellMap.remove(Point(cell.x, cell.y));
    }

    // 3. Move cluster
    for (final cell in cluster.cells) {
      cell.x += dx;
      cell.y += dy;
    }

    // 4. Re-register positions
    for (final cell in cluster.cells) {
      cellMap[Point(cell.x, cell.y)] = cluster.id;
    }

    return true;
  }

  // =========================================================
  // GRID SYNC (FOR YOUR CURRENT RENDERER)
  // =========================================================

  void _syncGridFromClusters() {
    // reset grid
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        grid[y][x] = null;
      }
    }

    // rebuild from clusters
    for (final cluster in clusters.values) {
      for (final cell in cluster.cells) {
        if (isInside(cell.x, cell.y)) {
          grid[cell.y][cell.x] = cell.color;
        }
      }
    }
  }

  /// Returns `true` if there is **any** connected group of cells with
  /// the given `color` that touches both the left wall (x=0) and the
  /// right wall (x = cols-1).
  ///
  /// Uses 4-way connectivity (up/down/left/right). Change the directions
  /// array to 8-way if you want diagonal connections to count as "touching".
  bool doesColorSpanLeftToRight(Color color) {
    if (!_isStable) return false; // only check for bridges when stable

    // Fast early-out: does this color even exist on both walls?
    bool touchesLeft = false;
    bool touchesRight = false;

    for (int y = 0; y < rows; y++) {
      if (grid[y][0] == color) touchesLeft = true;
      if (grid[y][cols - 1] == color) touchesRight = true;
    }
    if (!touchesLeft || !touchesRight) return false;

    // Flood-fill from the left wall
    final visited = List.generate(rows, (_) => List.filled(cols, false));

    final queue = <Point<int>>[]; // BFS queue

    // Seed all cells on the left wall with this color
    for (int y = 0; y < rows; y++) {
      if (grid[y][0] == color && !visited[y][0]) {
        visited[y][0] = true;
        queue.add(Point(0, y));
      }
    }

    const directions = [
      // ← 4-way
      Point(1, 0), Point(-1, 0),
      Point(0, 1), Point(0, -1),
      // For 8-way add these two lines:
      // Point(1, 1), Point(1, -1),
      // Point(-1, 1), Point(-1, -1),
    ];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);

      // We reached the right wall → bridge found!
      if (current.x == cols - 1) return true;

      for (final dir in directions) {
        final nx = current.x + dir.x;
        final ny = current.y + dir.y;

        if (nx >= 0 &&
            nx < cols &&
            ny >= 0 &&
            ny < rows &&
            !visited[ny][nx] &&
            grid[ny][nx] == color) {
          visited[ny][nx] = true;
          queue.add(Point(nx, ny));
        }
      }
    }

    return false; // no path reached the right wall
  }

  /// Clears ONLY the connected sand pile (same color) that spans
  /// from the left wall to the right wall.
  /// Returns `true` if a bridge was found and cleared.
  bool clearSpanningBridge(Color color) {
    if (!doesColorSpanLeftToRight(color)) return false; // only clear if a bridge exists
    if (!_isStable) return false; // only clear when stable to avoid weird edge cases

    // Fast early-out
    bool touchesLeft = false;
    bool touchesRight = false;
    for (int y = 0; y < rows; y++) {
      if (grid[y][0] == color) touchesLeft = true;
      if (grid[y][cols - 1] == color) touchesRight = true;
    }
    if (!touchesLeft || !touchesRight) return false;

    final visited = List.generate(rows, (_) => List.filled(cols, false));
    final queue = <Point<int>>[];
    final toClear = <Point<int>>[]; // ← only these cells will be removed

    const directions = [
      Point(1, 0), Point(-1, 0),
      Point(0, 1), Point(0, -1),
      // Point(1, 1), Point(1, -1), Point(-1, 1), Point(-1, -1), // 8-way if you want
    ];

    // Seed from left wall
    for (int y = 0; y < rows; y++) {
      if (grid[y][0] == color && !visited[y][0]) {
        visited[y][0] = true;
        queue.add(Point(0, y));
        toClear.add(Point(0, y));
      }
    }

    bool reachesRight = false;

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);

      if (current.x == cols - 1) {
        reachesRight = true;
      }

      for (final dir in directions) {
        final nx = current.x + dir.x;
        final ny = current.y + dir.y;

        if (nx >= 0 &&
            nx < cols &&
            ny >= 0 &&
            ny < rows &&
            !visited[ny][nx] &&
            grid[ny][nx] == color) {
          visited[ny][nx] = true;
          queue.add(Point(nx, ny));
          toClear.add(Point(nx, ny));
        }
      }
    }

    if (!reachesRight) return false;

    // === REMOVE ONLY THE BRIDGE CELLS ===
    for (final p in toClear) {
      grid[p.y][p.x] = null;
      cellMap.remove(p);
    }

    // Clean up any clusters that lost cells (keeps physics consistent)
    _cleanupStaleClusters();

    return true;
  }

  /// Internal helper: remove clusters whose cells no longer exist
  void _cleanupStaleClusters() {
    final idsToRemove = <int>[];
    for (final entry in clusters.entries) {
      final cluster = entry.value;
      final stillValid = cluster.cells.any((cell) {
        final pt = Point(cell.x, cell.y);
        return cellMap.containsKey(pt);
      });
      if (!stillValid) idsToRemove.add(entry.key);
    }
    for (final id in idsToRemove) {
      clusters.remove(id);
    }
  }

  // =========================================================
  // OPTIONAL: FUTURE SPLIT SUPPORT (SAFE PLACEHOLDER)
  // =========================================================

  /// Later upgrade: if clusters break apart, rebuild them here.
  void rebuildClustersFromGrid() {
    // intentionally left empty for now
    // (this is where flood-fill clustering would go later)
  }
}
