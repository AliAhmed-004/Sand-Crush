import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:sand_crush/game.dart';

void main() {
  runApp(const SandCrush());
}

class SandCrush extends StatelessWidget {
  const SandCrush({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: GameWidget(game: SandGame()),
    );
  }
}
