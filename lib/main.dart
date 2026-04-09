import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:sand_crush/game.dart';
import 'package:sand_crush/ui/hud_overlay.dart';

void main() {
  runApp(const SandCrush());
}

class SandCrush extends StatelessWidget {
  const SandCrush({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sand Crush',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        body: Stack(
          children: [
            GameWidget(game: SandGame()),
            const HudOverlay(),
          ],
        ),
      ),
    );
  }
}
