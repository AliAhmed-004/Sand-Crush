Sand Crush – Performance Optimizations
This document explains the key performance improvements recommended after profiling the game on an Android device in profile mode.
Current State (After Profiling)

Memory: Excellent (~8.3 MB heap, stable)
Main Issue: High number of Cluster + Cell objects (often ~3200 each)
Symptom: Occasional frame-time spikes when many small clusters exist
Strength: Batched drawVertices rendering is already efficient

The biggest bottleneck is cluster fragmentation — when large pieces break into thousands of single-cell clusters, both physics and grid syncing become expensive.
Recommended Fixes
1. Reduce Cluster Fragmentation (Highest Impact)
Problem: _breakApartCluster turns multi-cell pieces into many 1-cell clusters, leading to 3000+ objects.
Solution: Implement smart merging of same-color clusters that are touching.
What to do:

After the board becomes stable (isStable transitions to true), run a merging pass.
Merge adjacent 1-cell clusters of the same color into larger clusters.
Optionally, limit breaking apart: only break clusters larger than a certain size, or only when truly necessary.

Expected Benefit: Keep clusters.length under 500–1000 most of the time → much smoother physics and fewer GC pauses.
2. Optimize Grid Sync (_syncGridFromClusters)
Problem: Every physics sub-step you do fillRange(0, length, 0) + rewrite colors for all cells in all clusters.
Solutions (choose one or combine):

Dirty Region Tracking: Maintain a list or set of indices that changed since the last sync. Only clear and rewrite those positions.
Incremental Update: Instead of clearing the entire buffer every time, only update positions where a cell moved or was placed/removed.

Expected Benefit: Significantly reduces memory traffic in the hot update loop.
3. Cache UI Elements (Easy Wins)
A. "NEXT" TextPainter

Currently recreated and laid out every frame in _drawNextPiecePreview.
Fix: Make it a class field in SandGame, initialize and layout once in onLoad() or when the text changes.

B. Grid Lines

Drawing ~160 drawLine calls every frame is unnecessary.
Best Fix: Use PictureRecorder to record the grid lines once (on resize) into a ui.Picture, then draw the picture every frame with canvas.drawPicture().

Expected Benefit: Small but consistent reduction in render time.
4. Minor Physics Improvements

Cache clusters.values.toList() instead of creating it every sub-step.
Rebuild the list only when clusters are added or removed.
Consider reducing physics update rate to 30 Hz (_step = 1/30) if 60 Hz feels too heavy (many sand games do this).

5. Optional Advanced Optimizations

Implement a simple dirty rectangle system for rendering (only rebuild Vertices when something actually changed).
Use Union-Find (Disjoint Set Union) per color for faster bridge detection if needed later.

Priority Order (Recommended)

Cluster Merging — Biggest impact on spikes
Cache "NEXT" TextPainter + Grid Lines Picture — Quick & easy
Dirty sync for color buffer — Good medium-term win
Physics list caching