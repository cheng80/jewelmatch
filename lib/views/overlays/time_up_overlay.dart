import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_config.dart';
import '../../game/match_board_game.dart';
import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../vm/ranking_notifier.dart';
import '../../widgets/lumina_buttons.dart';
import '../../widgets/lumina_overlay_card.dart';

/// 타임 모드 종료 시 표시. 바운스 텍스트 연출 후 점수·랭킹 패널.
class TimeUpOverlay extends ConsumerStatefulWidget {
  const TimeUpOverlay({super.key, required this.game});
  final MatchBoardGame game;

  @override
  ConsumerState<TimeUpOverlay> createState() => _TimeUpOverlayState();
}

class _TimeUpOverlayState extends ConsumerState<TimeUpOverlay>
    with TickerProviderStateMixin {
  static const Duration _titleDuration = Duration(milliseconds: 1500);
  static const Duration _panelDelay = Duration(milliseconds: 1900);

  late final AnimationController _titleCtrl;
  late final Animation<double> _titleScale;
  late final Animation<double> _titleOpacity;

  bool _showPanel = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = AnimationController(vsync: this, duration: _titleDuration);

    _titleScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOutExpo)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 70,
      ),
    ]).animate(_titleCtrl);

    _titleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleCtrl, curve: const Interval(0, 0.15)),
    );

    _titleCtrl.forward();

    Future.delayed(_panelDelay, () {
      if (!mounted) return;
      setState(() => _showPanel = true);
      _submitScore();
    });
  }

  void _submitScore() {
    if (!widget.game.isTimedMode) return;
    ref.read(rankingProvider.notifier).submit(
          score: widget.game.board.score,
          trRankSuccess: context.tr('rankSuccess'),
          trRankNotInTop: context.tr('rankNotInTop'),
          trRankSubmitFailed: context.tr('rankSubmitFailed'),
        );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rankState = ref.watch(rankingProvider);

    if (!_showPanel) {
      return ColoredBox(
        color: JewelCandyLuminaTheme.overlayScrim,
        child: Center(
          child: AnimatedBuilder(
            animation: _titleCtrl,
            builder: (_, _) => Opacity(
              opacity: _titleOpacity.value,
              child: Transform.scale(
                scale: _titleScale.value,
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
                        color: JewelCandyLuminaTheme.primaryPink
                            .withValues(alpha: 0.8),
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
              color: JewelCandyLuminaTheme.tertiaryGold
                  .withValues(alpha: 0.95),
              fontSize: 22,
            ),
          ),
          Text(
            '${context.tr('score')}: ${widget.game.board.score}',
            style: TextStyle(
              color: JewelCandyLuminaTheme.goldStrong,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.game.isTimedMode) ...[
            const SizedBox(height: 12),
            if (rankState.isSubmitting)
              SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: JewelCandyLuminaTheme.secondaryCyan,
                ),
              )
            else if (rankState.rankMessage != null)
              Text(
                rankState.rankMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: JewelCandyLuminaTheme.tertiaryGold,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
          const SizedBox(height: 24),
          LuminaGradientButton(
            colors: JewelCandyLuminaTheme.buttonRetryMagOr,
            label: context.tr('retry'),
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              ref.read(rankingProvider.notifier).reset();
              widget.game.restartRound();
            },
          ),
          const SizedBox(height: 12),
          LuminaOutlinedButton(
            label: context.tr('exit'),
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              ref.read(rankingProvider.notifier).reset();
              context.go(RoutePaths.title);
            },
          ),
        ],
      ),
    );
  }
}
