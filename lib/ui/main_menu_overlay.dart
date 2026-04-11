import 'package:flutter/material.dart';
import 'package:sand_crush/config/game_config.dart';
import 'package:sand_crush/game.dart';
import 'package:sand_crush/services/high_score_service.dart';
import 'package:sand_crush/services/save_game_service.dart';
import 'package:sand_crush/services/scoring_service.dart';

/// Main menu overlay for the Sand Crush game.
class MainMenuOverlay extends StatelessWidget {
  final SandGame game;

  const MainMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final highScore = HighScoreService.instance.getHighScore();
    final hasSavedGame = SaveGameService.instance.hasSavedGame();

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
              const SizedBox(height: 30),
              Text(
                'High Score: $highScore',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 40),
              if (hasSavedGame)
                ElevatedButton(
                  onPressed: () {
                    game.loadSavedGame();
                    game.isGameStarted = true;
                    game.resumeEngine();
                    game.overlays.remove(GameConfig.mainMenuOverlay);
                    game.overlays.add(GameConfig.hudOverlay);
                  },
                  child: const Text('Continue Game'),
                ),
              if (hasSavedGame) const SizedBox(height: 16),
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
