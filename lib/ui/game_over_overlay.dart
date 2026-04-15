import 'package:flutter/material.dart';
import 'package:sandfall/config/game_config.dart';
import 'package:sandfall/game.dart';
import 'package:sandfall/services/high_score_service.dart';
import 'package:sandfall/services/scoring_service.dart';
import 'package:sandfall/theme/theme.dart';

/// Game Over overlay displayed when sand reaches the top threshold.
class GameOverOverlay extends StatelessWidget {
  final SandGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final finalScore = ScoringService.instance.currentScore;
    final highScore = HighScoreService.instance.getHighScore();
    final isNewRecord = finalScore > highScore;

    return Material(
      color: Colors.black.withAlpha(179), // Semi-transparent dark background
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 100),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: SandColors.mediumBg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: SandColors.deepSand, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GAME OVER',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: SandColors.warmAccent,
                ),
              ),
              const SizedBox(height: 20),
              if (isNewRecord)
                const Text(
                  '🎉 NEW RECORD! 🎉',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: SandColors.primaryGold,
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'Final Score: $finalScore',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: SandColors.lightSand,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'High Score: $highScore',
                style: const TextStyle(
                  fontSize: 18,
                  color: SandColors.sandyBeige,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  game.overlays.remove(GameConfig.gameOverOverlay);
                  game.overlays.add(GameConfig.mainMenuOverlay);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Return to Menu',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
