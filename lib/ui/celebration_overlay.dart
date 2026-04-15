import 'package:flutter/material.dart';
import 'package:sandfall/config/game_config.dart';
import 'package:sandfall/game.dart';
import 'package:sandfall/theme/theme.dart';


/// Celebration overlay for the Sand Crush game, shown when the player reaches a milestone.
/// 
/// This overlay displays a congratulatory message 
class CelebrationOverlay extends StatelessWidget {
  final SandGame game;
  const CelebrationOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(179), // Semi-transparent dark background
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 50),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: SandColors.sandyBeige,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: SandColors.deepSand, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(102),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '✨ Milestone Reached! ✨',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: SandColors.primaryGold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Great progress!',
                style: TextStyle(
                  fontSize: 18,
                  color: SandColors.deepSand,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  game.overlays.remove(GameConfig.celebrationOverlay);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 30),
                  backgroundColor: SandColors.warmAccent,
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}