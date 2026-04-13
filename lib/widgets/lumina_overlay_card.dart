import 'package:flutter/material.dart';

import '../theme/jewel_candy_lumina_theme.dart';

/// 오버레이 공통 구조: 스크림 + 중앙 카드.
///
/// [borderColor]로 오버레이 종류별 테두리 색상을 구분한다.
/// [child]는 카드 내부 콘텐츠.
class LuminaOverlayCard extends StatelessWidget {
  const LuminaOverlayCard({
    super.key,
    required this.child,
    this.borderColor,
    this.shadowColor,
    this.horizontalMargin = 24,
    this.horizontalPadding = 32,
    this.verticalPadding = 28,
    this.scrollable = false,
  });

  final Widget child;
  final Color? borderColor;
  final Color? shadowColor;
  final double horizontalMargin;
  final double horizontalPadding;
  final double verticalPadding;

  /// true이면 카드 내부를 SingleChildScrollView로 감싼다 (PauseMenu 등).
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: JewelCandyLuminaTheme.surfaceContainer.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor ?? JewelCandyLuminaTheme.borderPause,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: (shadowColor ?? JewelCandyLuminaTheme.primaryDeep)
                .withValues(alpha: 0.4),
            blurRadius: 22,
          ),
        ],
      ),
      child: child,
    );

    Widget inner = card;
    if (scrollable) {
      inner = SingleChildScrollView(child: card);
    }

    return ColoredBox(
      color: JewelCandyLuminaTheme.overlayScrim,
      child: Center(child: inner),
    );
  }
}
