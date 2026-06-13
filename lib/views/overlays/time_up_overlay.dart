import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_config.dart';
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
    final rankingScore = widget.game.isProgressionMode
        ? widget.game.progressionLevel
        : widget.game.board.score;
    ref
        .read(rankingProvider.notifier)
        .submit(
          mode: rankingMode,
          score: rankingScore,
          trRankSuccess: context.tr(
            rankingMode == RankingMode.level
                ? 'rankLevelSuccess'
                : 'rankSuccess',
          ),
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
    if (!_showPanel) {
      return _TimeUpIntroTitle(
        controller: _titleCtrl,
        opacity: _titleOpacity,
        scale: _titleScale,
      );
    }

    return _TimeUpResultPanel(
      game: widget.game,
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
  const _RankStatusSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubmitting = ref.watch(
      rankingProvider.select((state) => state.isSubmitting),
    );
    final rankMessage = ref.watch(
      rankingProvider.select((state) => state.rankMessage),
    );

    if (isSubmitting) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: JewelCandyLuminaTheme.secondaryCyan,
        ),
      );
    }

    if (rankMessage == null) {
      return const SizedBox.shrink();
    }

    return Text(
      rankMessage,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: JewelCandyLuminaTheme.tertiaryGold,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
