import 'package:flutter/material.dart';

import '../resources/asset_paths.dart';
import 'jewel_candy_lumina_theme.dart';

/// 앱 전역 테마. 게임 [JewelCandyLuminaTheme]과 동일한 팔레트·폰트로 통일한다.
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AssetPaths.fontNexonLv2Gothic,
    colorScheme: ColorScheme.dark(
      primary: JewelCandyLuminaTheme.primaryPink,
      onPrimary: Colors.white,
      primaryContainer: JewelCandyLuminaTheme.surfaceVariant,
      onPrimaryContainer: Colors.white,
      secondary: JewelCandyLuminaTheme.secondaryCyan,
      onSecondary: Colors.black,
      secondaryContainer: JewelCandyLuminaTheme.surfaceContainer,
      onSecondaryContainer: Colors.white,
      tertiary: JewelCandyLuminaTheme.tertiaryGold,
      surface: JewelCandyLuminaTheme.surface,
      onSurface: Colors.white,
      surfaceContainerHighest: JewelCandyLuminaTheme.surfaceContainer,
      error: const Color(0xFFFFB4AB),
      onError: Colors.black,
      outline: JewelCandyLuminaTheme.outlineBright,
    ),
    scaffoldBackgroundColor: JewelCandyLuminaTheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: JewelCandyLuminaTheme.surfaceContainer,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        fontFamily: AssetPaths.fontNexonLv2Gothic,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: JewelCandyLuminaTheme.surfaceVariant,
      contentTextStyle: const TextStyle(
        fontFamily: AssetPaths.fontNexonLv2Gothic,
        color: Colors.white,
        fontSize: 16,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: JewelCandyLuminaTheme.secondaryCyan,
      textColor: Colors.white.withValues(alpha: 0.95),
    ),
    dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.12)),
    switchTheme: JewelCandyLuminaTheme.obsidianSwitchTheme(),
    sliderTheme: JewelCandyLuminaTheme.obsidianSliderTheme(
      const SliderThemeData(),
    ),
  );
}
