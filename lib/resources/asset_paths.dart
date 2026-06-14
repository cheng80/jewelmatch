/// 에셋 경로 상수.
/// 하드코딩을 피하고 한곳에서 관리한다.
class AssetPaths {
  AssetPaths._();

  /// 효과음 경로. FlameAudio.play()에는 assets/audio/ 이후 상대 경로를 전달한다.
  static const String sfxTimeTic = 'sfx/TimeTic.mp3';
  static const String sfxStart = 'sfx/Start.wav';
  static const String sfxCollect = 'sfx/Collect.mp3';
  static const String sfxFail = 'sfx/Fail.mp3';

  /// 클리어 등에 사용할 수 있는 SFX (`assets/audio/sfx/Clear.wav`).
  static const String sfxClear = 'sfx/Clear.wav';
  static const String sfxBtnSnd = 'sfx/BtnSnd.mp3';

  /// 진행 모드 레벨업 콜아웃.
  static const String sfxLevelUp = 'sfx/LevelUp.wav';

  /// 진행 모드 레벨업 색종이 버스트.
  static const String sfxConfetti = 'sfx/Confetti.mp3';

  /// 콤보 2단계 이상 연쇄 시 상승 차임.
  static const String sfxComboHit = 'sfx/ComboHit.mp3';

  /// 4개 이상 매치 시 화려한 버스트.
  static const String sfxBigMatch = 'sfx/BigMatch.mp3';

  /// 특수 보석(스트라이프/폭탄/하이퍼) 발동 시.
  static const String sfxSpecialGem = 'sfx/SpecialGem.mp3';

  /// 타임 모드 시간 종료(`TimeUp` 오버레이). 클리어/승리 스팅이 아닌 **타임 오버** 톤용.
  static const String sfxTimeUp = 'sfx/TimeUp.wav';

  /// BGM 경로. FlameAudio.bgm에는 assets/audio/ 이후 상대 경로를 전달한다.
  static const String bgmMenu = 'music/Menu_BGM.mp3';
  static const String bgmMain = 'music/Main_BGM.mp3';

  /// 폰트 family 이름 (pubspec.yaml에 등록된 이름과 동일)
  static const String fontNexonLv2Gothic = 'NexonLv2Gothic';

  /// 7열×128px 보석 스프라이트 시트 (색은 코드에서 열 인덱스로 매핑)
  static const String jewelSpriteSheet = 'sprites/Jewel_Arcane.png';

  /// 3열×128px 특수 보석 시트 (순서: legacy col, legacy row, flame)
  static const String specialSpriteSheet = 'sprites/Special_Arcane.png';

  /// 12열×128px 충전 보석 시트 (순서: star 1~6색, supernova 1~6색)
  static const String chargedSpriteSheet = 'sprites/Charged_Arcane.png';

  /// Obsidian Rune Temple 나인패치 프레임.
  static const String obsidianPanelFrame =
      'assets/images/ui/obsidian_panel_frame.png';

  /// Obsidian Rune Temple 원형 아이콘 버튼 프레임.
  static const String obsidianIconButtonFrame =
      'ui/obsidian_icon_button_frame.png';

  /// 힌트 버튼용 금속 전구 아이콘.
  static const String obsidianHintBulbIcon = 'ui/obsidian_hint_bulb_icon.png';

  /// 튜토리얼 버튼용 금속 안내 아이콘.
  static const String obsidianTutorialIcon = 'ui/obsidian_tutorial_icon.png';

  /// 일시정지 버튼용 금속 pause 아이콘.
  static const String obsidianPauseIcon = 'ui/obsidian_pause_icon.png';

  /// 랭킹 버튼용 금속 왕관 아이콘.
  static const String obsidianRankingCrownIcon =
      'ui/obsidian_ranking_crown_icon.png';
}
