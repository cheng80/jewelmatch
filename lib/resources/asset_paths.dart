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

  /// 2열×128px legacy 특수 보석 시트 (순서: legacy col, legacy row)
  static const String specialSpriteSheet = 'sprites/Special_Arcane.png';

  /// 4열×128px 액션 특수 보석 시트 (순서: bomb, star, hyper, supernova)
  static const String specialActionSpriteSheet =
      'sprites/Special_Action_Arcane.png';

  /// 범위형 특수 이펙트 atlas 제어 manifest.
  static const String specialAreaEffectManifest =
      'sprites/special_area_effects.json';

  /// Bomb 범위형 특수 이펙트 4×4 시트.
  static const String specialAreaEffectBomb = 'sprites/Special_Area_Bomb.png';

  /// Hyper 범위형 특수 이펙트 4×4 시트.
  static const String specialAreaEffectHyper = 'sprites/Special_Area_Hyper.png';

  /// Supernova 범위형 특수 이펙트 4×4 시트.
  static const String specialAreaEffectSupernova =
      'sprites/Special_Area_Supernova.png';

  /// 레거시 폭탄 보석용 독립 오버레이. 현재 메인 보드 렌더에서는 사용하지 않는다.
  static const String flameOverlay = 'sprites/flame_overlay.png';

  /// 별 보석용 독립 오버레이.
  static const String starOverlay = 'sprites/star_overlay.png';

  /// 레거시 초신성 보석용 독립 오버레이. 현재 메인 보드 렌더에서는 사용하지 않는다.
  static const String supernovaOverlay = 'sprites/supernova_overlay.png';

  /// 고대 판타지 유적 배경. Flutter 위젯에서는 전체 assets 경로를 사용한다.
  static const String ancientRuinsSpaceBackground =
      'assets/images/backgrounds/ancient_ruins_space_bg.png';

  /// 고대 판타지 유적 배경. Flame image cache에서는 assets/images 이후 경로를 사용한다.
  static const String ancientRuinsSpaceBackgroundFlame =
      'backgrounds/ancient_ruins_space_bg.png';

  /// Obsidian Rune Temple 나인패치 프레임.
  static const String obsidianPanelFrame =
      'assets/images/ui/obsidian_panel_frame.png';

  /// Obsidian Rune Temple 나인패치 프레임. Flame image cache용.
  static const String obsidianPanelFrameFlame = 'ui/obsidian_panel_frame.png';

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

  static const String itemIconRuneHammer = 'ui/item_icons/rune_hammer.png';
  static const String itemIconAncientBomb = 'ui/item_icons/ancient_bomb.png';
  static const String itemIconThorHammer = 'ui/item_icons/thor_hammer.png';
  static const String itemIconHyperCube = 'ui/item_icons/hyper_cube.png';
  static const String itemIconPrismTransform =
      'ui/item_icons/prism_transform.png';
  static const String itemIconFateShuffle = 'ui/item_icons/fate_shuffle.png';
  static const String itemIconTimeSlip = 'ui/item_icons/time_slip.png';
  static const String itemIconHintPlus = 'ui/item_icons/hint_plus.png';

  static const String stoneMatchTitle =
      'assets/images/ui/stone_match_title.png';
  static const String modeButtonPanelBase =
      'assets/images/ui/mode_buttons/mode_button_panel_base.png';
  static const String modeButtonFrameFront =
      'assets/images/ui/mode_buttons/mode_button_frame_front.png';
  static const String normalButtonTintBg =
      'assets/images/ui/normal_buttons/normal_button_tint_bg.png';
  static const String normalButtonFrontFrame =
      'assets/images/ui/normal_buttons/normal_button_front_frame.png';
  static const String modeIconSimple =
      'assets/images/ui/mode_icons/mode_icon_simple_infinity_256.png';
  static const String modeIconProgression =
      'assets/images/ui/mode_icons/mode_icon_progression_256.png';
  static const String modeIconTimed =
      'assets/images/ui/mode_icons/mode_icon_timed_hourglass_256.png';
  static const String modeIconSettings =
      'assets/images/ui/mode_icons/mode_icon_settings_gear_256.png';
  static const String modeIconRanking =
      'assets/images/ui/mode_icons/mode_icon_ranking_crown_256.png';
  static const String modeIconInventory =
      'assets/images/ui/mode_icons/mode_icon_inventory_256.png';
}
