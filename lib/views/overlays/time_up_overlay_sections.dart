part of 'time_up_overlay.dart';

class _TimeUpIntroTitle extends StatelessWidget {
  const _TimeUpIntroTitle({
    required this.controller,
    required this.opacity,
    required this.scale,
  });

  final AnimationController controller;
  final Animation<double> opacity;
  final Animation<double> scale;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: JewelCandyLuminaTheme.overlayScrim,
      child: Center(
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, _) => Opacity(
            opacity: opacity.value,
            child: Transform.scale(
              scale: scale.value,
              child: Text(
                context.tr('timeUpTitle'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  shadows: [
                    Shadow(
                      color: JewelCandyLuminaTheme.primaryPink,
                      blurRadius: 30,
                    ),
                    Shadow(
                      color: JewelCandyLuminaTheme.primaryPink.withValues(
                        alpha: 0.8,
                      ),
                      blurRadius: 60,
                    ),
                    Shadow(
                      color: JewelCandyLuminaTheme.primaryDeep,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeUpResultPanel extends StatelessWidget {
  const _TimeUpResultPanel({
    required this.game,
    required this.onRetry,
    required this.onExit,
  });

  final MatchBoardGame game;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return LuminaOverlayCard(
      borderColor: JewelCandyLuminaTheme.borderTimeUp,
      shadowColor: JewelCandyLuminaTheme.primaryPink,
      horizontalPadding: 40,
      verticalPadding: 36,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('timeUpTitle'),
            style: TextStyle(
              color: JewelCandyLuminaTheme.secondaryCyan,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('gameResult'),
            style: TextStyle(
              color: JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.95),
              fontSize: 22,
            ),
          ),
          Text(
            '${context.tr('score')}: ${game.board.score}',
            style: TextStyle(
              color: JewelCandyLuminaTheme.goldStrong,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (game.isTimedMode) ...[
            const SizedBox(height: 12),
            const _RankStatusSection(),
          ],
          const SizedBox(height: 24),
          LuminaGradientButton(
            colors: JewelCandyLuminaTheme.buttonRetryMagOr,
            label: context.tr('retry'),
            onPressed: onRetry,
          ),
          const SizedBox(height: 12),
          LuminaOutlinedButton(label: context.tr('exit'), onPressed: onExit),
        ],
      ),
    );
  }
}
