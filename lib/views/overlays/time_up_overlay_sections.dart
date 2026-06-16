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
                  color: JewelCandyLuminaTheme.textTitleGold,
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
      maxHeightFactor: 0.72,
      verticalMargin: 86,
      alignment: Alignment.topCenter,
      horizontalPadding: 28,
      verticalPadding: 24,
      innerPadding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('timeUpTitle'),
            style: TextStyle(
              color: JewelCandyLuminaTheme.textTitleGold,
              fontSize: 34,
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
            '${game.board.score}',
            style: TextStyle(
              color: JewelCandyLuminaTheme.goldStrong,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (game.hasTimedClock) ...[
            const SizedBox(height: 12),
            const _RankStatusSection(),
          ],
          const SizedBox(height: 22),
          LuminaGradientButton(
            colors: JewelCandyLuminaTheme.buttonRetryMagOr,
            label: context.tr('retry'),
            onPressed: onRetry,
          ),
          const SizedBox(height: 14),
          LuminaOutlinedButton(
            label: context.tr('statsButton'),
            borderColor: JewelCandyLuminaTheme.tertiaryGold,
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              game.showGameStats();
            },
          ),
          const SizedBox(height: 14),
          LuminaOutlinedButton(label: context.tr('exit'), onPressed: onExit),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
