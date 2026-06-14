import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../game/match_board_game.dart';
import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../widgets/lumina_buttons.dart';
import '../../widgets/lumina_overlay_card.dart';

class LevelUpOverlay extends StatefulWidget {
  const LevelUpOverlay({super.key, required this.game});

  final MatchBoardGame game;

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.8,
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 70,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 30),
    ]).animate(_controller);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: LuminaOverlayCard(
          borderColor: JewelCandyLuminaTheme.goldStrong,
          shadowColor: JewelCandyLuminaTheme.tertiaryGold,
          maxCardWidth: 410,
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
                context.tr('levelUpTitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: JewelCandyLuminaTheme.goldStrong,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _LevelBadge(game: game),
              if (game.progressionNextBoardBonusCount > 0) ...[
                const SizedBox(height: 16),
                Text(
                  context.tr(
                    'nextBoardBonus',
                    namedArgs: {
                      'count': '${game.progressionNextBoardBonusCount}',
                    },
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: JewelCandyLuminaTheme.tertiaryGold,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                context.tr('levelUpDesc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: JewelCandyLuminaTheme.textParchment,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: LuminaGradientButton(
                  width: 260,
                  colors: JewelCandyLuminaTheme.buttonShuffleCyanLime,
                  label: context.tr('nextLevel'),
                  onPressed: () {
                    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                    game.continueAfterLevelUp();
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.game});

  final MatchBoardGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: JewelCandyLuminaTheme.surfaceVariant.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.8),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            '${context.tr('levelLabel')} ${game.levelUpFromLevel}',
            style: TextStyle(
              color: JewelCandyLuminaTheme.textParchment.withValues(
                alpha: 0.72,
              ),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            Icons.keyboard_double_arrow_down_rounded,
            color: JewelCandyLuminaTheme.focusTeal,
            size: 30,
          ),
          const SizedBox(height: 4),
          Text(
            '${context.tr('levelLabel')} ${game.levelUpToLevel}',
            style: TextStyle(
              color: JewelCandyLuminaTheme.goldStrong,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
