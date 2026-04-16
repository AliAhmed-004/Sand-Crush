import 'package:flutter/material.dart';
import 'package:sandfall/config/game_config.dart';
import 'package:sandfall/game.dart';
import 'package:sandfall/services/high_score_service.dart';
import 'package:sandfall/services/save_game_service.dart';
import 'package:sandfall/services/scoring_service.dart';
import 'package:sandfall/theme/theme.dart';

class MainMenuOverlay extends StatelessWidget {
  final SandGame game;

  const MainMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final highScore = HighScoreService.instance.getHighScore();
    final hasSavedGame = SaveGameService.instance.hasSavedGame();
    final savedScore = SaveGameService.instance.getSavedScore();

    return Material(
      color: SandColors.darkBg,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(flex: 2),

                const _GameTitle(),

                const SizedBox(height: 48),

                _HighScoreCard(score: highScore),

                const SizedBox(height: 48),

                if (hasSavedGame) ...[
                  _MenuButton(
                    label: 'CONTINUE',
                    sublabel: 'Score: $savedScore',
                    onPressed: () {
                      game.loadSavedGame();
                      game.isGameStarted = true;
                      game.resumeEngine();
                      game.overlays.remove(GameConfig.mainMenuOverlay);
                      game.overlays.add(GameConfig.hudOverlay);
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                _MenuButton(
                  label: 'START GAME',
                  onPressed: () {
                    SaveGameService.instance.deleteSavedGame();
                    game.resetGameState();
                    ScoringService.instance.resetScore();
                    game.isGameStarted = true;
                    game.resumeEngine();

                    game.overlays.remove(GameConfig.mainMenuOverlay);

                    game.overlays.add(GameConfig.hudOverlay);
                  },
                ),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameTitle extends StatelessWidget {
  const _GameTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'SAND',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: SandColors.primaryGold.withAlpha(200),
            letterSpacing: 8,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          'FALL',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: SandColors.primaryGold.withAlpha(200),
            letterSpacing: 8,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _HighScoreCard extends StatelessWidget {
  final int score;

  const _HighScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'HIGH SCORE',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 3,
            color: SandColors.lightSand.withAlpha(120),
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          score.toString(),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w300,
            color: SandColors.primaryGold.withAlpha(180),
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final String? sublabel;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.label,
    this.sublabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: SandColors.primaryGold.withAlpha(180),
          side: BorderSide(color: SandColors.deepSand.withAlpha(80), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 3,
                fontFamily: 'monospace',
              ),
            ),
            if (sublabel != null)
              Text(
                sublabel!,
                style: TextStyle(
                  fontSize: 9,
                  color: SandColors.lightSand.withAlpha(100),
                  fontFamily: 'monospace',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

