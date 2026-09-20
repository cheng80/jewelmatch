import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/jewel_candy_lumina_theme.dart';
import 'obsidian_frame.dart';
import 'overlay_motion.dart';

/// 오버레이 공통 구조: 스크림 + 중앙 카드.
///
/// [borderColor]로 오버레이 종류별 테두리 색상을 구분한다.
/// [child]는 카드 내부 콘텐츠.
///
/// 카드는 공통 등장 전환([OverlayEnterTransition])을 두르고 나온다. 이 카드를 쓰는
/// 오버레이는 등장 연출을 따로 만들지 않는다. 스크림은 연출하지 않는다.
/// 화면 전체에 애니메이션 알파 합성을 걸지 않기 위해서다.
class LuminaOverlayCard extends StatelessWidget {
  const LuminaOverlayCard({
    super.key,
    required this.child,
    this.borderColor,
    this.shadowColor,
    this.horizontalMargin = 24,
    this.horizontalPadding = 24,
    this.verticalPadding = 22,
    this.innerPadding = const EdgeInsets.all(16),
    this.verticalMargin = 34,
    this.maxCardWidth = 342,
    this.maxHeightFactor = 0.88,
    this.alignment = Alignment.center,
    this.scrollable = false,
    this.enterSlide = Offset.zero,
  });

  final Widget child;
  final Color? borderColor;
  final Color? shadowColor;
  final double horizontalMargin;
  final double horizontalPadding;
  final double verticalPadding;
  final EdgeInsetsGeometry innerPadding;
  final double verticalMargin;
  final double maxCardWidth;
  final double maxHeightFactor;
  final AlignmentGeometry alignment;

  /// true이면 카드 내부를 SingleChildScrollView로 감싼다 (PauseMenu 등).
  final bool scrollable;

  /// 등장할 때 카드가 출발하는 위치. 카드 크기 대비 비율이다.
  /// `Offset(0, 0.12)`이면 아래에서 올라오며 자리 잡는다 (스테이지 인벤토리).
  final Offset enterSlide;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: JewelCandyLuminaTheme.overlayScrim,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = math.max(
            0.0,
            constraints.maxWidth - (horizontalMargin * 2),
          );
          final cardWidth = math.min(maxCardWidth, availableWidth);
          final availableHeight = math.max(
            0.0,
            constraints.maxHeight - (verticalMargin * 2),
          );
          final cardMaxHeight = math.min(
            constraints.maxHeight * maxHeightFactor,
            availableHeight,
          );

          Widget cardChild = child;
          if (scrollable) {
            cardChild = SingleChildScrollView(child: child);
          }

          return Padding(
            padding: EdgeInsets.symmetric(vertical: verticalMargin),
            child: Align(
              alignment: alignment,
              child: OverlayEnterTransition(
                slideFrom: enterSlide,
                child: Container(
                  width: cardWidth,
                  constraints: BoxConstraints(maxHeight: cardMaxHeight),
                  margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
                  child: Material(
                    color: Colors.transparent,
                    child: ObsidianFrame(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      backgroundColor: JewelCandyLuminaTheme.surfaceContainer
                          .withValues(alpha: 0.96),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                (borderColor ??
                                        JewelCandyLuminaTheme.borderPause)
                                    .withValues(alpha: 0.28),
                          ),
                        ),
                        child: Padding(padding: innerPadding, child: cardChild),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
