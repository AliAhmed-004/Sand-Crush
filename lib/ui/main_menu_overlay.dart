import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sand_crush/config/game_config.dart';
import 'package:sand_crush/game.dart';
import 'package:sand_crush/services/high_score_service.dart';
import 'package:sand_crush/services/save_game_service.dart';
import 'package:sand_crush/services/scoring_service.dart';
import 'package:sand_crush/theme/theme.dart';

/// Sand particle for animation
class _SandParticle {
  late double x;
  late double y;
  late double vx;
  late double vy;
  late double opacity;
  late double scale;
  final math.Random _random = math.Random();

  _SandParticle(double centerX, double centerY, double width) {
    reset(centerX, centerY, width);
  }

  void reset(double centerX, double centerY, double width) {
    // Start from random position around the title
    x = centerX + ((_random.nextDouble() - 0.5) * width * 0.8);
    y = centerY - (_random.nextDouble() * 40 + 20);
    
    // Gentle horizontal drift
    vx = (_random.nextDouble() - 0.5) * 40;
    
    // Falling velocity
    vy = _random.nextDouble() * 30 + 50;
    
    opacity = _random.nextDouble() * 0.7 + 0.3;
    scale = _random.nextDouble() * 0.6 + 0.4;
  }

  void update(double dt, double centerX, double centerY, double width, double height) {
    x += vx * dt;
    y += vy * dt;
    
    // Fade out as it falls
    opacity -= dt * 0.3;
    
    // Reset if it goes off screen
    if (y > height || opacity <= 0) {
      reset(centerX, centerY, width);
    }
  }

  void paint(Canvas canvas, double size) {
    if (opacity <= 0) return;
    
    canvas.drawCircle(
      Offset(x, y),
      size * scale,
      Paint()
        ..color = SandColors.primaryGold.withAlpha((opacity * 255).toInt())
        ..style = PaintingStyle.fill,
    );
  }
}

/// Main menu overlay for the Sand Crush game.
class MainMenuOverlay extends StatefulWidget {
  final SandGame game;

  const MainMenuOverlay({super.key, required this.game});

  @override
  State<MainMenuOverlay> createState() => _MainMenuOverlayState();
}

class _MainMenuOverlayState extends State<MainMenuOverlay>
    with TickerProviderStateMixin {
  late AnimationController _particleController;
  late AnimationController _fadeController;
  late List<_SandParticle> _particles;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    // Particle animation - continuous loop
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Fade-in animation - one time only
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Initialize particles
    _particles = List.generate(20, (i) => _SandParticle(0, 0, 100));

    _particleController.addListener(_updateParticles);
  }

  void _updateParticles() {
    setState(() {
      const dt = 0.016; // ~60fps
      for (final particle in _particles) {
        particle.update(dt, 0, 0, 300, 600);
      }
    });
  }

  @override
  void dispose() {
    _particleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highScore = HighScoreService.instance.getHighScore();
    // final hasSavedGame = SaveGameService.instance.hasSavedGame();
    // final savedScore = SaveGameService.instance.getSavedScore();

    return Material(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              SandColors.darkBg,
              SandColors.mediumBg,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeIn,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title with particle animation
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Particle background
                      SizedBox(
                        width: 300,
                        height: 120,
                        child: CustomPaint(
                          painter: _ParticlePainter(_particles),
                        ),
                      ),
                      // Title text
                      const Text(
                        'SAND CRUSH',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: SandColors.primaryGold,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(
                              offset: Offset(2, 2),
                              blurRadius: 8,
                              color: Color(0x80000000),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Decorative separator
                  Container(
                    width: 200,
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          SandColors.deepSand,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // High score section
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: SandColors.primaryGold,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: SandColors.deepSand.withAlpha(51), // 20% opacity
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'HIGH SCORE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: SandColors.lightSand,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          highScore.toString(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: SandColors.primaryGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Buttons section
                  Column(
                    children: [
                      // if (hasSavedGame) ...[
                      //   _MenuButton(
                      //     label: 'Continue Game - Score: $savedScore',
                      //     onPressed: () {
                      //       widget.game.loadSavedGame();
                      //       widget.game.isGameStarted = true;
                      //       widget.game.resumeEngine();
                      //       widget.game.overlays
                      //           .remove(GameConfig.mainMenuOverlay);
                      //       widget.game.overlays.add(GameConfig.hudOverlay);
                      //     },
                      //     color: SandColors.warmAccent,
                      //   ),
                      //   const SizedBox(height: 12),
                      // ],
                      _MenuButton(
                        label: 'Start New Game',
                        onPressed: () {
                          // SaveGameService.instance.deleteSavedGame();
                          widget.game.resetGameState();
                          ScoringService.instance.resetScore();
                          widget.game.isGameStarted = true;
                          widget.game.resumeEngine();
                          widget.game.overlays
                              .remove(GameConfig.mainMenuOverlay);
                          widget.game.overlays.add(GameConfig.hudOverlay);
                        },
                        color: SandColors.warmAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom button for the menu
class _MenuButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const _MenuButton({
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          width: 350,
          height: 60,
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: _isHovered ? 8 : 2,
            ),
            child: Text(
              widget.label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for rendering sand particles
class _ParticlePainter extends CustomPainter {
  final List<_SandParticle> particles;

  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      particle.paint(canvas, 3.0);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
