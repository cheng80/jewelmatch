import 'package:flutter/material.dart';

/// Stitch **Jewel Candy Lumina** 팔레트 (프로젝트 `18005744607178433216`).
/// 생성 HTML: [design/stitch/main_gameplay_redesign.html]
abstract final class JewelCandyLuminaTheme {
  static const Color surface = Color(0xFF190033);
  static const Color surfaceVariant = Color(0xFF390069);
  static const Color surfaceContainer = Color(0xFF29004D);

  static const Color primaryPink = Color(0xFFFF86C1);
  static const Color primaryDeep = Color(0xFFFF6BB9);
  static const Color secondaryCyan = Color(0xFF00FBFB);
  static const Color tertiaryGold = Color(0xFFFFE792);
  static const Color goldStrong = Color(0xFFFFD700);
  static const Color outlineBright = Color(0xFF8D61BD);

  /// 보드 안쪽 패널 · 슬롯 — 배경은 **어둡게** 두어 스프라이트 보석이 튀도록 함 (HUD는 그대로 화사).
  static const Color boardInner = Color(0xFF0E0618);
  static const Color boardSlotFill = Color(0xFF2A1A42);
  static const Color boardSlotStroke = Color(0xFF4A3D5C);

  /// 외곽 프레임: 채도는 유지하되 전체 톤 다운(보석 대비)
  static const List<Color> boardFrameGradient = [
    Color(0xFF6B0D52),
    Color(0xFF3D1F6E),
    Color(0xFF0D5A6E),
  ];

  /// 콤보 스트립 글래스 카드
  static const List<Color> comboStripGradient = [
    Color(0xFFFF6BB9),
    Color(0xFFAB47BC),
    Color(0xFF00E5FF),
  ];

  /// 타임바 충분할 때: 라임 → 골드 → 핫핑크
  static const List<Color> timeBarFillVibrant = [
    Color(0xFF76FF03),
    Color(0xFFFFEA00),
    Color(0xFFFF4081),
  ];

  static const List<Color> timeBarFillCritical = [
    Color(0xFFFF1744),
    Color(0xFFFF8A80),
  ];

  /// 반투명 보라 스크림
  static const Color overlayScrim = Color(0xB3190033);

  static const Color borderPause = Color(0xFFFF4081);
  static const Color borderNoMoves = Color(0xFF00E676);
  static const Color borderTimeUp = Color(0xFFFFD700);

  static const List<Color> buttonPrimaryPink = [
    Color(0xFFFF6BB9),
    Color(0xFFFF4081),
  ];

  static const List<Color> buttonRetryMagOr = [
    Color(0xFFFF00AA),
    Color(0xFFFF6E40),
  ];

  static const List<Color> buttonShuffleCyanLime = [
    Color(0xFF00E5FF),
    Color(0xFF76FF03),
  ];
}
