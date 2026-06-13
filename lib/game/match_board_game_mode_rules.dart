part of 'match_board_game.dart';

extension MatchBoardGameModeRules on MatchBoardGame {
  static const double timedRoundSeconds = 60;
  static const double timedMaxTimeSeconds = 90;
  static const double timedModeTimeRewardScale = 0.6;
  static const int timedModeBonusBaseUnits = 1;
  static const int timedModeBonusPerComboTierUnits = 1;
  static const double progressionModeTimeRewardScale = 0.6;
  static const int progressionModeBonusBaseUnits = 1;
  static const int progressionModeBonusPerComboTierUnits = 1;

  bool get isTimedMode => gameMode == JewelGameMode.timed;
  bool get isProgressionMode => gameMode == JewelGameMode.progression;
  bool get hasTimedClock => isTimedMode || isProgressionMode;

  double get roundSecondsForMode =>
      isProgressionMode ? timedRoundSeconds : timedRoundSeconds;

  double get maxTimeSecondsForMode =>
      isProgressionMode ? timedMaxTimeSeconds : timedMaxTimeSeconds;

  double get timeRewardScaleForMode => isProgressionMode
      ? progressionModeTimeRewardScale
      : timedModeTimeRewardScale;

  int get timeBonusBaseUnitsForMode => isProgressionMode
      ? progressionModeBonusBaseUnits
      : timedModeBonusBaseUnits;

  int get timeBonusPerComboTierUnitsForMode => isProgressionMode
      ? progressionModeBonusPerComboTierUnits
      : timedModeBonusPerComboTierUnits;
}
