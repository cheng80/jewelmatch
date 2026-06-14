import 'package:flutter/material.dart';

/// Stitch **Jewel Candy Lumina** 팔레트 (프로젝트 `18005744607178433216`).
/// 생성 HTML: [design/stitch/main_gameplay_redesign.html]
abstract final class JewelCandyLuminaTheme {
  static const Color surface = Color(0xFF080A0F);
  static const Color surfaceVariant = Color(0xFF171A20);
  static const Color surfaceContainer = Color(0xFF111318);
  static const Color surfaceStone = Color(0xFF171511);
  static const Color surfaceStoneDark = Color(0xFF0B0C0B);

  static const Color primaryPink = Color(0xFFC64235);
  static const Color primaryDeep = Color(0xFF7B241C);
  static const Color secondaryCyan = Color(0xFF36C7C0);
  static const Color tertiaryGold = Color(0xFFE4C174);
  static const Color goldStrong = Color(0xFFC98A32);
  static const Color outlineBright = Color(0xFF9E7A44);

  /// 보드 안쪽 패널 · 슬롯 — 배경은 **어둡게** 두어 스프라이트 보석이 튀도록 함 (HUD는 그대로 화사).
  static const Color boardInner = Color(0xFF090B0D);
  static const Color boardSlotFill = Color(0xFF1B1B18);
  static const Color boardSlotStroke = Color(0xFF4E422B);

  /// 외곽 프레임: 보석보다 한 단계 뒤로 물러나는 밤하늘 톤.
  static const List<Color> boardFrameGradient = [
    Color(0xFF544022),
    Color(0xFF1E2326),
    Color(0xFF0C5653),
  ];

  /// 콤보 스트립 글래스 카드
  static const List<Color> comboStripGradient = [
    Color(0xFF15130F),
    Color(0xFF312719),
    Color(0xFF123D3A),
  ];

  /// 타임바 충분할 때: 민트 → 골드 → 베리핑크
  static const List<Color> timeBarFillVibrant = [
    Color(0xFF35CFC4),
    Color(0xFFD7AA52),
    Color(0xFF8A332A),
  ];

  static const List<Color> timeBarFillCritical = [
    Color(0xFFB3211E),
    Color(0xFFE08732),
  ];

  /// 반투명 보라 스크림
  static const Color overlayScrim = Color(0xC906080C);

  static const Color borderPause = Color(0xFFC98A32);
  static const Color borderNoMoves = Color(0xFF36C7C0);
  static const Color borderTimeUp = Color(0xFFE0B257);

  static const List<Color> buttonPrimaryPink = [
    Color(0xFF2B625E),
    Color(0xFF143734),
  ];

  static const List<Color> buttonRetryMagOr = [
    Color(0xFF5B2D1C),
    Color(0xFF2B1610),
  ];

  static const List<Color> buttonShuffleCyanLime = [
    Color(0xFF4B3420),
    Color(0xFF1B1B18),
  ];

  static SliderThemeData obsidianSliderTheme(SliderThemeData base) {
    return base.copyWith(
      trackHeight: 12,
      activeTrackColor: secondaryCyan,
      inactiveTrackColor: surfaceStone,
      disabledActiveTrackColor: secondaryCyan.withValues(alpha: 0.25),
      disabledInactiveTrackColor: surfaceStone.withValues(alpha: 0.55),
      thumbColor: tertiaryGold,
      disabledThumbColor: outlineBright.withValues(alpha: 0.45),
      overlayColor: secondaryCyan.withValues(alpha: 0.16),
      activeTickMarkColor: goldStrong.withValues(alpha: 0.4),
      inactiveTickMarkColor: outlineBright.withValues(alpha: 0.2),
      trackShape: const RoundedRectSliderTrackShape(),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
    );
  }

  static SwitchThemeData obsidianSwitchTheme() {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return outlineBright.withValues(alpha: 0.45);
        }
        if (states.contains(WidgetState.selected)) {
          return tertiaryGold;
        }
        return outlineBright;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return surfaceStone.withValues(alpha: 0.45);
        }
        if (states.contains(WidgetState.selected)) {
          return secondaryCyan.withValues(alpha: 0.48);
        }
        return surfaceStone.withValues(alpha: 0.82);
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return goldStrong.withValues(alpha: 0.82);
        }
        return outlineBright.withValues(alpha: 0.65);
      }),
    );
  }
}
