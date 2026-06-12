import 'package:flutter/material.dart';

/// Stitch **Jewel Candy Lumina** 팔레트 (프로젝트 `18005744607178433216`).
/// 생성 HTML: [design/stitch/main_gameplay_redesign.html]
abstract final class JewelCandyLuminaTheme {
  static const Color surface = Color(0xFF130824);
  static const Color surfaceVariant = Color(0xFF25133E);
  static const Color surfaceContainer = Color(0xFF1E0E33);

  static const Color primaryPink = Color(0xFFF48AB6);
  static const Color primaryDeep = Color(0xFFD75A96);
  static const Color secondaryCyan = Color(0xFF74D7E2);
  static const Color tertiaryGold = Color(0xFFF4D58A);
  static const Color goldStrong = Color(0xFFF2BE54);
  static const Color outlineBright = Color(0xFF7B6BA2);

  /// 보드 안쪽 패널 · 슬롯 — 배경은 **어둡게** 두어 스프라이트 보석이 튀도록 함 (HUD는 그대로 화사).
  static const Color boardInner = Color(0xFF0B1020);
  static const Color boardSlotFill = Color(0xFF1B2340);
  static const Color boardSlotStroke = Color(0xFF35405C);

  /// 외곽 프레임: 보석보다 한 단계 뒤로 물러나는 밤하늘 톤.
  static const List<Color> boardFrameGradient = [
    Color(0xFF3B245D),
    Color(0xFF253760),
    Color(0xFF1D5662),
  ];

  /// 콤보 스트립 글래스 카드
  static const List<Color> comboStripGradient = [
    Color(0xFFE37DA9),
    Color(0xFF8B6CC8),
    Color(0xFF6FD0D8),
  ];

  /// 타임바 충분할 때: 민트 → 골드 → 베리핑크
  static const List<Color> timeBarFillVibrant = [
    Color(0xFF65D6A6),
    Color(0xFFF4C764),
    Color(0xFFE86F9D),
  ];

  static const List<Color> timeBarFillCritical = [
    Color(0xFFE74E5B),
    Color(0xFFF2A45F),
  ];

  /// 반투명 보라 스크림
  static const Color overlayScrim = Color(0xB30B1020);

  static const Color borderPause = Color(0xFFE86F9D);
  static const Color borderNoMoves = Color(0xFF65D6A6);
  static const Color borderTimeUp = Color(0xFFF2BE54);

  static const List<Color> buttonPrimaryPink = [
    Color(0xFFF48AB6),
    Color(0xFFD94C87),
  ];

  static const List<Color> buttonRetryMagOr = [
    Color(0xFFF1A45E),
    Color(0xFFE45E78),
  ];

  static const List<Color> buttonShuffleCyanLime = [
    Color(0xFF68DDB7),
    Color(0xFF43BBD0),
  ];
}
