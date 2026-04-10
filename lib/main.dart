import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:sand_crush/config/game_config.dart';
import 'package:sand_crush/game.dart';
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
      theme: ThemeData(primarySwatch: Colors.blue),
      home: GameWidget.controlled(
        gameFactory: () => game,
        overlayBuilderMap: {
          GameConfig.mainMenuOverlay: (context, game) =>
              MainMenuOverlay(game: game as SandGame),
          GameConfig.hudOverlay: (context, game) => HudOverlay(), // Placeholder for HUD overlay
        },
        initialActiveOverlays: [GameConfig.mainMenuOverlay],
      ),
    );
  }
}
