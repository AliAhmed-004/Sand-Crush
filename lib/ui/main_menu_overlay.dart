import 'package:flutter/material.dart';
import 'package:sand_crush/config/game_config.dart';
import 'package:sand_crush/game.dart';
import 'package:sand_crush/services/scoring_service.dart';

/// Main menu overlay for the Sand Crush game.
class MainMenuOverlay extends StatelessWidget {
  final SandGame game;

  const MainMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        padding: const EdgeInsets.all(20),
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sand Crush',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              ElevatedButton(
                onPressed: () {
                  game.resetGameState();
                  ScoringService.instance.resetScore();
                  game.isGameStarted = true;
                  game.resumeEngine();
                  game.overlays.remove(GameConfig.mainMenuOverlay);
                  game.overlays.add(GameConfig.hudOverlay);
                },
                child: const Text('Start Game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
