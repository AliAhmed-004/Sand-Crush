import 'package:flutter/material.dart';
import 'package:sand_crush/config/game_config.dart';
import 'package:sand_crush/game.dart';


/// Pause overlay for the Sand Crush game.
/// 
/// Shows options to resume, restart, return to menu, and toggle sound/haptics.
class PauseOverlay extends StatefulWidget {
  final SandGame game;

  const PauseOverlay({super.key, required this.game});

  @override
  State<PauseOverlay> createState() => _PauseOverlayState();
}

class _PauseOverlayState extends State<PauseOverlay> {
  bool _soundEnabled = true;
  bool _hapticEnabled = true;

  @override
  void initState() {
    super.initState();
    widget.game.pauseEngine();
  }

  void _resume() {
    widget.game.resumeEngine();
    widget.game.overlays.remove(GameConfig.pauseOverlay);
  }

  void _restart() {
    widget.game.resetGameState();
    widget.game.resumeEngine();
    widget.game.overlays.remove(GameConfig.pauseOverlay);
  }

  void _mainMenu() {
    widget.game.resetGameState();
    widget.game.resumeEngine();
    widget.game.overlays.remove(GameConfig.pauseOverlay);
    widget.game.overlays.remove(GameConfig.hudOverlay);
    widget.game.overlays.add(GameConfig.mainMenuOverlay);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(179), // Semi-transparent dark background
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24, width: 2),
          ),
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PAUSED',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),

                // Resume Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _resume,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text(
                      'Resume',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Restart Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _restart,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text(
                      'Restart Game',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Main Menu Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _mainMenu,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Main Menu',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Settings Section
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),

                // Sound Effects Toggle
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sound Effects',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      Switch(
                        value: _soundEnabled,
                        onChanged: (value) {
                          setState(() {
                            _soundEnabled = value;
                          });
                          // TODO: Implement sound toggle
                        },
                        activeThumbColor: Colors.blue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Haptic Feedback Toggle
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Haptic Feedback',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      Switch(
                        value: _hapticEnabled,
                        onChanged: (value) {
                          setState(() {
                            _hapticEnabled = value;
                          });
                          // TODO: Implement haptic toggle
                        },
                        activeThumbColor: Colors.blue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
