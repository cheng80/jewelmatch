import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/match_board_game.dart';
import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../theme/jewel_candy_lumina_theme.dart';

class LevelCelebrationOverlay extends StatefulWidget {
  const LevelCelebrationOverlay({super.key, required this.game});

  final MatchBoardGame game;

  @override
  State<LevelCelebrationOverlay> createState() =>
      _LevelCelebrationOverlayState();
}

class _LevelCelebrationOverlayState extends State<LevelCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confetti;
  late final List<_CelebrationParticle> _particles;

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _particles = _buildParticles();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _confetti.forward(from: 0);
      SoundManager.playSfx(AssetPaths.sfxConfetti);
      Future<void>.delayed(const Duration(milliseconds: 3000), () {
        if (mounted) widget.game.showLevelUpPopupAfterCelebration();
      });
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.36),
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _UpwardConfettiPainter(
                      progress: _confetti.value,
                      particles: _particles,
                    ),
                  );
                },
              ),
            ),
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.84, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Text(
                  'LEVEL UP',
                  style: TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    color: JewelCandyLuminaTheme.tertiaryGold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.86),
                        offset: const Offset(0, 3),
                        blurRadius: 10,
                      ),
                      Shadow(
                        color: JewelCandyLuminaTheme.goldStrong.withValues(
                          alpha: 0.65,
                        ),
                        offset: Offset.zero,
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_CelebrationParticle> _buildParticles() {
    final random = math.Random(20260614);
    final colors = <Color>[
      JewelCandyLuminaTheme.tertiaryGold,
      JewelCandyLuminaTheme.goldStrong,
      JewelCandyLuminaTheme.outlineBright,
      JewelCandyLuminaTheme.dangerRed,
      JewelCandyLuminaTheme.focusTeal,
    ];
    final launchers = <({double x, double y, double direction, int count})>[
      (x: 0.27, y: 40, direction: -math.pi * 0.58, count: 48),
      (x: 0.5, y: 50, direction: -math.pi / 2, count: 70),
      (x: 0.73, y: 40, direction: -math.pi * 0.42, count: 48),
      (x: 0.41, y: 26, direction: -math.pi * 0.55, count: 20),
      (x: 0.59, y: 26, direction: -math.pi * 0.45, count: 20),
    ];

    return [
      for (final launcher in launchers)
        for (var i = 0; i < launcher.count; i++)
          _CelebrationParticle(
            xFactor: launcher.x,
            belowBottom: launcher.y + random.nextDouble() * 18,
            direction: launcher.direction + (random.nextDouble() - 0.5) * 0.24,
            speed: 760 + random.nextDouble() * 520,
            delayMs: random.nextDouble() * 1750,
            color: colors[random.nextInt(colors.length)],
            width: 7 + random.nextDouble() * 8,
            height: 4 + random.nextDouble() * 6,
            spin: (random.nextDouble() - 0.5) * 14,
            drift: (random.nextDouble() - 0.5) * 28,
          ),
    ];
  }
}

class _CelebrationParticle {
  const _CelebrationParticle({
    required this.xFactor,
    required this.belowBottom,
    required this.direction,
    required this.speed,
    required this.delayMs,
    required this.color,
    required this.width,
    required this.height,
    required this.spin,
    required this.drift,
  });

  final double xFactor;
  final double belowBottom;
  final double direction;
  final double speed;
  final double delayMs;
  final Color color;
  final double width;
  final double height;
  final double spin;
  final double drift;
}

class _UpwardConfettiPainter extends CustomPainter {
  const _UpwardConfettiPainter({
    required this.progress,
    required this.particles,
  });

  static const _durationMs = 2800.0;
  static const _gravity = 220.0;

  final double progress;
  final List<_CelebrationParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final elapsedMs = progress * _durationMs;
    for (final particle in particles) {
      final localMs = elapsedMs - particle.delayMs;
      if (localMs < 0) continue;

      final t = localMs / 1000.0;
      final fade = (1 - (localMs / (_durationMs - particle.delayMs))).clamp(
        0.0,
        1.0,
      );
      if (fade <= 0) continue;

      final x0 = size.width * particle.xFactor;
      final y0 = size.height + particle.belowBottom;
      final x =
          x0 +
          math.cos(particle.direction) * particle.speed * t +
          math.sin(t * math.pi * 3) * particle.drift;
      final y =
          y0 +
          math.sin(particle.direction) * particle.speed * t +
          _gravity * t * t;

      if (y > size.height + 80 || x < -80 || x > size.width + 80) continue;

      final paint = Paint()
        ..color = particle.color.withValues(alpha: fade)
        ..style = PaintingStyle.fill;
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: particle.width,
        height: particle.height,
      );
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(particle.spin * t)
        ..drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant _UpwardConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.particles != particles;
}
