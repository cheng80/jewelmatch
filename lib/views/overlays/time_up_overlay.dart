import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_config.dart';
import '../../ads/ad_reward_policy.dart';
import '../../ads/ad_service.dart';
import '../../game/match_board_game.dart';
import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../services/ranking_service.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../vm/ranking_notifier.dart';
import '../../widgets/lumina_buttons.dart';
import '../../widgets/lumina_overlay_card.dart';

part 'time_up_overlay_sections.dart';

/// 타임 모드 종료 시 표시. 바운스 텍스트 연출 후 점수·랭킹 패널.
class TimeUpOverlay extends ConsumerStatefulWidget {
  const TimeUpOverlay({
    super.key,
    required this.game,
    required this.adService,
    required this.adRewardPolicy,
  });
  final MatchBoardGame game;
  final AdService adService;
  final AdRewardPolicy adRewardPolicy;

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
  bool _showingAd = false;
  String? _adMessage;

  @override
  void initState() {
    super.initState();
    _titleCtrl = AnimationController(vsync: this, duration: _titleDuration);

    _titleScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.35,
        ).chain(CurveTween(curve: Curves.easeOutExpo)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.35,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
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
    if (!widget.game.hasTimedClock) return;
    final rankingMode = widget.game.isProgressionMode
        ? RankingMode.level
        : RankingMode.time;
    ref
        .read(rankingProvider.notifier)
        .submit(
          mode: rankingMode,
          score: widget.game.rankingScore,
          trRankSuccess: context.tr(
            rankingMode == RankingMode.level
                ? 'rankLevelSuccess'
                : 'rankSuccess',
          ),
          trRankNotInTop: context.tr('rankNotInTop'),
          trRankNotFound: context.tr('rankNotFound'),
          trRankLoadFailed: context.tr('rankLoadFailed'),
          trRankSaveFailed: context.tr('rankSaveFailed'),
          trRankSubmitFailed: context.tr('rankSubmitFailed'),
          trIntossLevelRankSubmitFailed: context.tr(
            'intossLevelRankSubmitFailed',
          ),
        );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _continueWithAd() async {
    if (_showingAd ||
        widget.adService.rewardedState != RewardedAdState.ready ||
        !widget.adRewardPolicy.canContinueStage(widget.game.stageAttemptId)) {
      return;
    }
    SoundManager.pauseBgm(onlyIfCurrent: AssetPaths.bgmMain);
    setState(() {
      _showingAd = true;
      _adMessage = null;
    });
    final result = await widget.adService.showRewarded(
      AdPlacement.continueStage,
    );
    if (!mounted) return;
    final granted = widget.adRewardPolicy.grantContinue(
      widget.game.stageAttemptId,
      result,
    );
    if (granted) {
      ref.read(rankingProvider.notifier).reset();
      widget.game.continueStageAfterAd();
    } else {
      SoundManager.resumeBgm(onlyIfCurrent: AssetPaths.bgmMain);
      setState(() {
        _showingAd = false;
        _adMessage = context.tr('adRewardNotGranted');
      });
    }
    unawaited(widget.adService.preloadRewarded());
  }

  @override
  Widget build(BuildContext context) {
    if (!_showPanel) {
      return _TimeUpIntroTitle(opacity: _titleOpacity, scale: _titleScale);
    }

    return _TimeUpResultPanel(
      game: widget.game,
      adService: widget.adService,
      canContinueWithAd:
          widget.game.isProgressionMode &&
          widget.adService.rewardedState != RewardedAdState.unavailable &&
          widget.adRewardPolicy.canContinueStage(widget.game.stageAttemptId),
      showingAd: _showingAd,
      adMessage: _adMessage,
      onContinueWithAd: _continueWithAd,
      onRetryRanking: _submitScore,
      onRetry: () {
        SoundManager.playSfx(AssetPaths.sfxBtnSnd);
        ref.read(rankingProvider.notifier).reset();
        widget.game.restartRound();
      },
      onExit: () {
        SoundManager.playSfx(AssetPaths.sfxBtnSnd);
        ref.read(rankingProvider.notifier).reset();
        context.go(RoutePaths.title);
      },
    );
  }
}

class _RankStatusSection extends ConsumerWidget {
  const _RankStatusSection({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubmitting = ref.watch(
      rankingProvider.select((state) => state.isSubmitting),
    );
    final rankMessage = ref.watch(
      rankingProvider.select((state) => state.rankMessage),
    );
    final submitted = ref.watch(
      rankingProvider.select((state) => state.submitted),
    );

    if (isSubmitting) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: JewelCandyLuminaTheme.focusTeal,
        ),
      );
    }

    if (rankMessage == null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rankMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: JewelCandyLuminaTheme.tertiaryGold,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (!submitted)
          IconButton(
            tooltip: context.tr('rankRetrySubmit'),
            onPressed: onRetry,
            color: JewelCandyLuminaTheme.focusTeal,
            iconSize: 28,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    );
  }
}
