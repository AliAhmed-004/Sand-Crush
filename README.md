# Sand Crush

Sand Crush is a small sand-physics puzzle game built with Flutter and Flame.
You place the next “chunk” of sand onto a grid, let it settle under gravity,
and score by creating same-color bridges that span from the left edge to the
right edge.

## Gameplay

- Place pieces by tapping/clicking on the grid.
- Pieces fall with simple cluster-based gravity and can break into grains.
- When the board becomes stable, any connected bridge of a color that spans
	**left → right** clears.
- Score increases from placing pieces and clearing bridges; clears can chain
	into combos while the board keeps becoming unstable/stable.
- Difficulty ramps up by unlocking additional colors as you hit score
	milestones.

### Controls

- **Tap / click** a cell to place the next piece (only when the board is
	stable).
- Use the **Pause** button in the HUD to pause/resume or restart.

## Scoring & difficulty (high level)

- **Placement points** are awarded for every successful placement.
- **Clear points** are awarded based on the size of the cleared bridge and a
	combo bonus.
- **Milestones** occur every **25,000** points; the game starts with **3**
	colors available and unlocks **+1 color per milestone** (up to 6).

## Game over

The game ends when sand reaches the **top 10% of the grid**. A red horizontal
line is rendered to show the threshold.

## Save data

This project uses Hive for local persistence:

- **High score** is stored across sessions.
- **Saved game** (grid + score) is stored periodically (currently every 5
	successful placements). If a save exists, the main menu shows **Continue
	Game**.

## Run it

### Prerequisites

- Flutter SDK (Dart SDK version in `pubspec.yaml` is `^3.11.4`)

### Commands

Fetch dependencies:

```bash
flutter pub get
```

Run on a device/emulator:

```bash
flutter run
```

Run on a specific platform (examples):

```bash
flutter run -d chrome
flutter run -d linux
flutter run -d android
```

## Development

Static analysis:

```bash
flutter analyze
```

Tests:

```bash
flutter test
```

## Code map

- `lib/main.dart` — app bootstrap, Hive init, Flame `GameWidget` + overlays
- `lib/game.dart` — main game loop, input, rendering, save/load hooks
- `lib/world.dart` — grid buffers, clusters/physics, bridge clear + game over
- `lib/services/` — scoring, milestones/difficulty, persistence
- `lib/ui/` — Flutter overlays (main menu, HUD, pause, celebration, game over)

## Performance notes

See `docs/performance_optimization.md` for profiling notes and optimizations.
