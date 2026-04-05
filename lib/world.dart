import 'dart:math';

/// -----------------------------
/// CELL MODEL
/// -----------------------------
class Cell {
  int x;
  int y;

  Cell(this.x, this.y);
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
  late List<List<bool>> grid;

  /// Active clusters in the world
  final Map<int, Cluster> clusters = {};

  /// Fast lookup: (x,y) → clusterId
  final Map<Point<int>, int> cellMap = {};

  int _nextClusterId = 1;

  SandWorld({required this.cols, required this.rows}) {
    grid = List.generate(rows, (_) => List.generate(cols, (_) => false));
  }

  // =========================================================
  // PUBLIC API
  // =========================================================

  /// Spawn a single cell as its own cluster (old behavior compatibility)
  void placeCell(int x, int y) {
    _createCluster([Cell(x, y)]);
  }

  /// Spawn a Tetris-like shape
  void placeShape(List<Point<int>> offsets, int originX, int originY) {
    final cells = offsets.map((o) {
      return Cell(originX + o.x, originY + o.y);
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
    // Process clusters in order (could be optimized with topological sort later)
    final clusterList = clusters.values.toList();

    // Try to move each cluster down, down-left, or down-right
    for (final cluster in clusterList) {
      // Skip if cluster was already removed in this frame
      if (!clusters.containsKey(cluster.id)) continue;

      // Try straight down first
      bool moved = _tryMoveCluster(cluster, 0, 1);

      // If can't move down, try down-left
      if (!moved) {
        moved = _tryMoveCluster(cluster, -1, 1);
      }

      // If can't move down-left, try down-right
      if (!moved) {
        moved = _tryMoveCluster(cluster, 1, 1);
      }

      // If all movement failed → it breaks apart and settles as sand
      if (!moved) {
        _breakApartCluster(cluster);
      }
    }
  }

  void _breakApartCluster(Cluster cluster) {
    // Remove the cluster from active simulation
    clusters.remove(cluster.id);

    // Create a single-cell cluster for each cell to settle independently
    for (final cell in cluster.cells) {
      if (!isInside(cell.x, cell.y)) continue;

      // Create a new cluster with just this cell
      _createCluster([Cell(cell.x, cell.y)]);
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
        grid[y][x] = false;
      }
    }

    // rebuild from clusters
    for (final cluster in clusters.values) {
      for (final cell in cluster.cells) {
        if (isInside(cell.x, cell.y)) {
          grid[cell.y][cell.x] = true;
        }
      }
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
