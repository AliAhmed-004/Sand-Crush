import 'package:flutter/material.dart';
import 'package:sand_crush/config/game_config.dart';
import 'package:sand_crush/game.dart';


/// Celebration overlay for the Sand Crush game, shown when the player reaches a milestone.
/// 
/// This overlay displays a congratulatory message 
class CelebrationOverlay extends StatelessWidget {
  final SandGame game;
  const CelebrationOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Congratulations! Milestone Reached!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  game.overlays.remove(GameConfig.celebrationOverlay);
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}