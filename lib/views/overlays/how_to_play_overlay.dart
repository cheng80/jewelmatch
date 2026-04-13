import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../game/match_board_game.dart';
import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../widgets/lumina_buttons.dart';

/// "?" 버튼으로 열리는 게임 설명 오버레이.
class HowToPlayOverlay extends StatelessWidget {
  const HowToPlayOverlay({super.key, required this.game});
  final MatchBoardGame game;

  static const double _gemSize = 36;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: JewelCandyLuminaTheme.overlayScrim,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: JewelCandyLuminaTheme.surfaceContainer
                .withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: JewelCandyLuminaTheme.secondaryCyan,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: JewelCandyLuminaTheme.primaryDeep
                    .withValues(alpha: 0.4),
                blurRadius: 22,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Text(
                  context.tr('howToPlayTitle'),
                  style: TextStyle(
                    color: JewelCandyLuminaTheme.secondaryCyan,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sectionTitle(context.tr('howToPlayGoal')),
                      const SizedBox(height: 6),
                      _bodyText(context.tr('howToPlayGoalDesc')),
                      const SizedBox(height: 16),
                      _sectionTitle(context.tr('howToPlayMatch')),
                      const SizedBox(height: 8),
                      _matchExample([0, 0, 0, 6, 3]),
                      const SizedBox(height: 6),
                      _bodyText(context.tr('howToPlayMatchDesc')),
                      const SizedBox(height: 16),
                      _sectionTitle(context.tr('howToPlaySwap')),
                      const SizedBox(height: 8),
                      _swapExample(),
                      const SizedBox(height: 6),
                      _bodyText(context.tr('howToPlaySwapDesc')),
                      const SizedBox(height: 16),
                      _sectionTitle(context.tr('howToPlayCombo')),
                      const SizedBox(height: 6),
                      _bodyText(context.tr('howToPlayComboDesc')),
                      const SizedBox(height: 16),
                      _sectionTitle(context.tr('howToPlayHint')),
                      const SizedBox(height: 6),
                      _bodyText(context.tr('howToPlayHintDesc')),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: LuminaGradientButton(
                  colors: JewelCandyLuminaTheme.buttonPrimaryPink,
                  label: context.tr('continueGame'),
                  onPressed: () {
                    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                    game.closeHowToPlay();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: JewelCandyLuminaTheme.tertiaryGold,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _bodyText(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _gemClip(int sheetCol) {
    return SizedBox(
      width: _gemSize,
      height: _gemSize,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: _gemSize * 7,
          maxHeight: _gemSize,
          alignment: Alignment.centerLeft,
          child: Transform.translate(
            offset: Offset(-_gemSize * sheetCol, 0),
            child: Image.asset(
              'assets/images/sprites/Juwel.png',
              width: _gemSize * 7,
              height: _gemSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _matchExample(List<int> cols) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < cols.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            decoration: i < 3
                ? BoxDecoration(
                    border: Border.all(
                      color: JewelCandyLuminaTheme.tertiaryGold
                          .withValues(alpha: 0.8),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: _gemClip(cols[i]),
          ),
        ],
      ],
    );
  }

  Widget _swapExample() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _gemClip(0),
        const SizedBox(width: 2),
        _gemClip(6),
        const SizedBox(width: 8),
        Icon(Icons.swap_horiz_rounded,
            color: JewelCandyLuminaTheme.secondaryCyan, size: 28),
        const SizedBox(width: 8),
        _gemClip(6),
        const SizedBox(width: 2),
        _gemClip(0),
      ],
    );
  }
}
