import 'package:flutter/material.dart';
import 'package:sand_crush/config/game_config.dart';
import 'package:sand_crush/game.dart';

class MainMenuOverlay extends StatelessWidget {
  final SandGame game;

  const MainMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.black,
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
