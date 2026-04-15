import 'dart:ui';

enum FloatingScoreType { tap, combo }

class FloatingScore {
  final int value;
  final Offset startPosition;
  double elapsed;

  static const tapDuration = 0.8;
  static const comboDuration = 1.2;
  static const tapSpeed = 60.0; // pixels per second upward
  static const comboSpeed = 80.0;
  static const tapSize = 18.0;
  static const comboSize = 24.0;

  final FloatingScoreType type;

  FloatingScore({
    required this.value,
    required this.startPosition,
    required this.type,
  }) : elapsed = 0;

  double get duration =>
      type == FloatingScoreType.tap ? tapDuration : comboDuration;
  double get speed => type == FloatingScoreType.tap ? tapSpeed : comboSpeed;
  double get fontSize => type == FloatingScoreType.tap ? tapSize : comboSize;

  Offset get currentPosition {
    return Offset(
      startPosition.dx,
      startPosition.dy - speed * elapsed,
    );
  }

  double get alpha {
    final progress = elapsed / duration;
    // Fade out in the last 40% of the animation
    if (progress > 0.6) {
      return 1.0 - ((progress - 0.6) / 0.4);
    }
    return 1.0;
  }

  double get scale {
    if (type == FloatingScoreType.combo && elapsed < 0.1) {
      // Quick scale-up at start for combo
      return 1.0 + (0.3 * (1.0 - elapsed / 0.1));
    }
    return 1.0;
  }

  bool get isExpired => elapsed >= duration;

  void update(double dt) {
    elapsed += dt;
  }
}