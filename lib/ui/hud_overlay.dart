import 'package:flutter/material.dart';
import 'package:sand_crush/services/milestone_service.dart';
import 'package:sand_crush/services/scoring_service.dart';

class HudOverlay extends StatefulWidget {
  const HudOverlay({super.key});

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  int _lastMilestone = 0;
  int _milestoneStart = 0;
  int _milestoneEnd = 25000;

  bool _isAnimatingMilestone = false;

  // NEW: store latest score during animation
  int? _pendingScore;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _progressAnimation = AlwaysStoppedAnimation(0.0);

    final initialScore = ScoringService.instance.currentScore;

    _lastMilestone = MilestoneService.instance.getCurrentMilestone(
      initialScore,
    );
    _milestoneStart = MilestoneService.instance.getMilestoneScore(
      _lastMilestone,
    );
    _milestoneEnd = MilestoneService.instance.getNextMilestoneScore(
      initialScore,
    );

    ScoringService.instance.scoreNotifier.addListener(_onScoreChanged);
  }

  @override
  void dispose() {
    ScoringService.instance.scoreNotifier.removeListener(_onScoreChanged);
    _progressController.dispose();
    super.dispose();
  }

  void _onScoreChanged() {
    final score = ScoringService.instance.currentScore;
    final newMilestone = MilestoneService.instance.getCurrentMilestone(score);

    // If animating, STORE latest score and bail
    if (_isAnimatingMilestone) {
      _pendingScore = score;
      return;
    }

    // Milestone crossed
    if (newMilestone > _lastMilestone) {
      _handleMilestoneCross(score, newMilestone);
      return;
    }

    // Normal progress update
    final progress =
        ((score - _milestoneStart) / (_milestoneEnd - _milestoneStart)).clamp(
          0.0,
          1.0,
        );

    _animateTo(progress);
  }

  Future<void> _handleMilestoneCross(int score, int newMilestone) async {
    _isAnimatingMilestone = true;

    final currentProgress = _progressAnimation.value;

    // STEP 1: Fill to 100%
    await _animateTo(1.0, from: currentProgress);

    // Tiny pause for visual satisfaction
    await Future.delayed(const Duration(milliseconds: 120));

    // STEP 2: Reset instantly
    _progressController.reset();
    _progressAnimation = AlwaysStoppedAnimation(0.0);

    // Update milestone AFTER fill
    _lastMilestone = newMilestone;
    _milestoneStart = MilestoneService.instance.getMilestoneScore(
      _lastMilestone,
    );
    _milestoneEnd = MilestoneService.instance.getNextMilestoneScore(score);

    setState(() {});

    // STEP 3: Animate overflow progress
    final overflowProgress =
        ((score - _milestoneStart) / (_milestoneEnd - _milestoneStart)).clamp(
          0.0,
          1.0,
        );

    await _animateTo(overflowProgress, from: 0.0);

    _isAnimatingMilestone = false;

    // Process any score updates that happened during animation
    if (_pendingScore != null) {
      _pendingScore = null;
      _onScoreChanged(); // re-sync with latest state
    }
  }

  Future<void> _animateTo(double target, {double? from}) async {
    _progressAnimation =
        Tween<double>(
          begin: from ?? _progressAnimation.value,
          end: target,
        ).animate(
          CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
        );

    _progressController.forward(from: 0);
    setState(() {});

    await _progressController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final score = ScoringService.instance.currentScore;

    return Positioned(
      top: 40,
      left: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score
          Text(
            'Score: $score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // Progress Bar
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              final progress = _progressAnimation.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Milestone ${_lastMilestone + 1} • Goal: $_milestoneEnd',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),

                  const SizedBox(height: 8),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.lerp(Colors.blue, Colors.purple, progress)!,
                        ),
                        minHeight: 24,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '$_milestoneStart → $_milestoneEnd',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
