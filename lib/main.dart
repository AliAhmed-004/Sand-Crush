import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:sand_crush/config/game_config.dart';
import 'package:sand_crush/game.dart';
import 'package:sand_crush/theme/theme.dart';
import 'package:sand_crush/ui/celebration_overlay.dart';
import 'package:sand_crush/ui/game_over_overlay.dart';
import 'package:sand_crush/ui/hud_overlay.dart';
import 'package:sand_crush/ui/main_menu_overlay.dart';

void main() {
  runApp(const SandCrush());
}

class SandCrush extends StatelessWidget {
  const SandCrush({super.key});

  @override
  Widget build(BuildContext context) {
    final game = SandGame();

    return MaterialApp(
      title: 'Sand Crush',
      theme: theme,
      home: GameWidget.controlled(
        gameFactory: () => game,
        overlayBuilderMap: {
          GameConfig.mainMenuOverlay: (context, game) =>
              MainMenuOverlay(game: game as SandGame),
          GameConfig.hudOverlay: (context, game) =>
              HudOverlay(), // Placeholder for HUD overlay
          GameConfig.celebrationOverlay: (context, game) =>
              CelebrationOverlay(game: game as SandGame),
          GameConfig.gameOverOverlay: (context, game) =>
              GameOverOverlay(game: game as SandGame),
        },
        initialActiveOverlays: [GameConfig.mainMenuOverlay],
      ),
    );
  }
}
