import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../game/match_board_game.dart';
import '../../game/match_board_logic.dart';
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
                      _sectionTitle(context.tr('howToPlaySpecial')),
                      const SizedBox(height: 6),
                      _bodyText(context.tr('howToPlaySpecialDesc')),
                      const SizedBox(height: 12),
                      _specialGemGuide(context),
                      const SizedBox(height: 14),
                      _sectionTitle(context.tr('howToPlaySpecialMakeTitle')),
                      const SizedBox(height: 8),
                      _specialCreationGuide(context),
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

  Widget _specialGemGuide(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _specialGemCard(
          context,
          kind: GemKind.row,
          gemSheetCol: 0,
          title: context.tr('howToPlaySpecialRowTitle'),
          desc: context.tr('howToPlaySpecialRowDesc'),
        ),
        _specialGemCard(
          context,
          kind: GemKind.col,
          gemSheetCol: 3,
          title: context.tr('howToPlaySpecialColTitle'),
          desc: context.tr('howToPlaySpecialColDesc'),
        ),
        _specialGemCard(
          context,
          kind: GemKind.bomb,
          gemSheetCol: 5,
          title: context.tr('howToPlaySpecialBombTitle'),
          desc: context.tr('howToPlaySpecialBombDesc'),
        ),
        _specialGemCard(
          context,
          kind: GemKind.hyper,
          gemSheetCol: 1,
          title: context.tr('howToPlaySpecialHyperTitle'),
          desc: context.tr('howToPlaySpecialHyperDesc'),
        ),
      ],
    );
  }

  Widget _specialGemCard(
    BuildContext context, {
    required GemKind kind,
    required int gemSheetCol,
    required String title,
    required String desc,
  }) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: _specialGemPreview(kind: kind, gemSheetCol: gemSheetCol),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: JewelCandyLuminaTheme.tertiaryGold,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _specialGemPreview({
    required GemKind kind,
    required int gemSheetCol,
  }) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: FittedBox(
              fit: BoxFit.contain,
              child: _gemClip(gemSheetCol),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              size: const Size(52, 52),
              painter: _SpecialGemMarkPainter(kind),
            ),
          ),
        ],
      ),
    );
  }

  Widget _specialCreationGuide(BuildContext context) {
    return Column(
      children: [
        _specialCreationRow(
          context,
          before: _creationMatchRow([0, 0, 0, 0]),
          afterKind: GemKind.row,
          afterSheetCol: 0,
          label: context.tr('howToPlaySpecialMakeRow'),
        ),
        const SizedBox(height: 10),
        _specialCreationRow(
          context,
          before: _creationMatchRow([3, 3, 3, 3, 3]),
          afterKind: GemKind.hyper,
          afterSheetCol: 1,
          label: context.tr('howToPlaySpecialMakeHyper'),
        ),
        const SizedBox(height: 10),
        _specialCreationRow(
          context,
          before: _creationCrossMatch(),
          afterKind: GemKind.bomb,
          afterSheetCol: 5,
          label: context.tr('howToPlaySpecialMakeBomb'),
        ),
      ],
    );
  }

  Widget _specialCreationRow(
    BuildContext context, {
    required Widget before,
    required GemKind afterKind,
    required int afterSheetCol,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.22),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 300;
          final beforeWidget = FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: before,
          );

          final labelText = Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: beforeWidget),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      color: JewelCandyLuminaTheme.secondaryCyan,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    _specialGemPreview(
                      kind: afterKind,
                      gemSheetCol: afterSheetCol,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: labelText),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: beforeWidget),
              Icon(
                Icons.arrow_forward_rounded,
                color: JewelCandyLuminaTheme.secondaryCyan,
                size: 20,
              ),
              const SizedBox(width: 10),
              _specialGemPreview(kind: afterKind, gemSheetCol: afterSheetCol),
              const SizedBox(width: 12),
              Expanded(child: labelText),
            ],
          );
        },
      ),
    );
  }

  Widget _creationMatchRow(List<int> cols) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < cols.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.8),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _gemClip(cols[i]),
          ),
        ],
      ],
    );
  }

  Widget _creationCrossMatch() {
    const c = 2;
    const cell = 42.0;
    return SizedBox(
      width: cell * 3,
      height: cell * 3,
      child: Stack(
        children: [
          Positioned(left: cell, top: 0, child: _highlightedGem(c)),
          Positioned(left: 0, top: cell, child: _highlightedGem(c)),
          Positioned(left: cell, top: cell, child: _highlightedGem(c)),
          Positioned(left: cell * 2, top: cell, child: _highlightedGem(c)),
          Positioned(left: cell, top: cell * 2, child: _highlightedGem(c)),
        ],
      ),
    );
  }

  Widget _highlightedGem(int sheetCol) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.8),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: _gemClip(sheetCol),
    );
  }
}

class _SpecialGemMarkPainter extends CustomPainter {
  const _SpecialGemMarkPainter(this.kind);

  final GemKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final ts = size.width;

    switch (kind) {
      case GemKind.normal:
        break;
      case GemKind.row:
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.92)
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(cx - ts * 0.18, cy), Offset(cx + ts * 0.18, cy), p);
        canvas.drawLine(
          Offset(cx - ts * 0.18, cy - 4),
          Offset(cx + ts * 0.18, cy - 4),
          p,
        );
        canvas.drawLine(
          Offset(cx - ts * 0.18, cy + 4),
          Offset(cx + ts * 0.18, cy + 4),
          p,
        );
      case GemKind.col:
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.92)
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(cx, cy - ts * 0.18), Offset(cx, cy + ts * 0.18), p);
        canvas.drawLine(
          Offset(cx - 4, cy - ts * 0.18),
          Offset(cx - 4, cy + ts * 0.18),
          p,
        );
        canvas.drawLine(
          Offset(cx + 4, cy - ts * 0.18),
          Offset(cx + 4, cy + ts * 0.18),
          p,
        );
      case GemKind.bomb:
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset(cx, cy), ts * 0.12, p);
        for (final off in [
          Offset(0, -ts * 0.16),
          Offset(ts * 0.12, -ts * 0.08),
          Offset(ts * 0.12, ts * 0.1),
          Offset(-ts * 0.12, ts * 0.1),
          Offset(-ts * 0.12, -ts * 0.08),
        ]) {
          canvas.drawLine(Offset(cx, cy), Offset(cx + off.dx, cy + off.dy), p);
        }
      case GemKind.hyper:
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.95)
          ..strokeWidth = 2.6
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(cx - ts * 0.16, cy), Offset(cx + ts * 0.16, cy), p);
        canvas.drawLine(Offset(cx, cy - ts * 0.16), Offset(cx, cy + ts * 0.16), p);
        canvas.drawLine(
          Offset(cx - ts * 0.11, cy - ts * 0.11),
          Offset(cx + ts * 0.11, cy + ts * 0.11),
          p,
        );
        canvas.drawLine(
          Offset(cx - ts * 0.11, cy + ts * 0.11),
          Offset(cx + ts * 0.11, cy - ts * 0.11),
          p,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _SpecialGemMarkPainter oldDelegate) {
    return oldDelegate.kind != kind;
  }
}
