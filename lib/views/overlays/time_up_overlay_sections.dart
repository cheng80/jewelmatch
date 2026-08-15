part of 'time_up_overlay.dart';

class _TimeUpIntroTitle extends StatelessWidget {
  const _TimeUpIntroTitle({required this.opacity, required this.scale});

  final Animation<double> opacity;
  final Animation<double> scale;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: JewelCandyLuminaTheme.overlayScrim,
      child: Center(
        child: FadeTransition(
          opacity: opacity,
          child: ScaleTransition(
            scale: scale,
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
    );
  }
}

class _TimeUpResultPanel extends StatelessWidget {
  const _TimeUpResultPanel({
    required this.game,
    required this.adService,
    required this.canContinueWithAd,
    required this.showingAd,
    required this.adMessage,
    required this.onContinueWithAd,
    required this.onRetryRanking,
    required this.onRetry,
    required this.onExit,
  });

  final MatchBoardGame game;
  final AdService adService;
  final bool canContinueWithAd;
  final bool showingAd;
  final String? adMessage;
  final VoidCallback onContinueWithAd;
  final VoidCallback onRetryRanking;
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
            _RankStatusSection(onRetry: onRetryRanking),
          ],
          const SizedBox(height: 22),
          if (canContinueWithAd) ...[
            AnimatedBuilder(
              animation: adService,
              builder: (context, _) {
                final ready =
                    adService.rewardedState == RewardedAdState.ready &&
                    !showingAd;
                return AbsorbPointer(
                  absorbing: !ready,
                  child: Opacity(
                    opacity: ready ? 1 : 0.55,
                    child: LuminaGradientButton(
                      colors: JewelCandyLuminaTheme.buttonShuffleCyanLime,
                      label: showingAd
                          ? context.tr('adPlaying')
                          : ready
                          ? context.tr('watchAdContinue')
                          : context.tr('adLoading'),
                      onPressed: onContinueWithAd,
                    ),
                  ),
                );
              },
            ),
            if (adMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                adMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: JewelCandyLuminaTheme.textMutedGold,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],
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
