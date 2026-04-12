import 'package:flutter/material.dart';
import 'package:sand_crush/config/game_config.dart';
import 'package:sand_crush/game.dart';
import 'package:sand_crush/services/high_score_service.dart';
import 'package:sand_crush/services/save_game_service.dart';
import 'package:sand_crush/services/scoring_service.dart';
import 'package:sand_crush/theme/theme.dart';

/// Main menu overlay for the Sand Crush game.
class MainMenuOverlay extends StatelessWidget {
  final SandGame game;

  const MainMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final highScore = HighScoreService.instance.getHighScore();
    final hasSavedGame = SaveGameService.instance.hasSavedGame();
    final savedScore = SaveGameService.instance.getSavedScore();

    return Material(
      child: Container(
        padding: const EdgeInsets.all(20),
        color: SandColors.darkBg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sand Crush',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: SandColors.primaryGold,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'High Score: $highScore',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: SandColors.lightSand,
                ),
              ),
              const SizedBox(height: 40),
              if (hasSavedGame) ...[
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
                const SizedBox(height: 8),
                Text(
                  'Score: ${savedScore ?? 0}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: SandColors.sandyBeige,
                  ),
                ),
                const SizedBox(height: 24),
              ],
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
