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

  /// 보드 텍스처 한 장. 보석, 특수 보석, 배지, 범위 효과 레이어 칸이 모두 들어 있다.
  /// `tools/atlas/board.json`으로 다시 만든다. 칸 이름과 좌표는 [boardAtlasManifest].
  static const String boardAtlas = 'sprites/board_atlas.webp';

  /// [boardAtlas]의 칸 좌표. Flutter 번들 경로는 `assets/images/` 뒤에 붙인다.
  static const String boardAtlasManifest = 'sprites/board_atlas.json';

  /// 고대 판타지 유적 배경. Flutter 위젯에서는 전체 assets 경로를 사용한다.
  static const String ancientRuinsSpaceBackground =
      'assets/images/backgrounds/ancient_ruins_space_bg.png';

  /// 고대 판타지 유적 배경. Flame image cache에서는 assets/images 이후 경로를 사용한다.
  static const String ancientRuinsSpaceBackgroundFlame =
      'backgrounds/ancient_ruins_space_bg.png';

  /// HUD와 UI 위젯의 작은 이미지(버튼 프레임, 아이콘, 나인패치 패널) 아틀라스. Flame 기준 경로.
  /// 칸 이름은 `UiFrames`. 원본은 assets/design/legacy/ui/, 설정은 tools/atlas/ui.json.
  static const String uiAtlas = 'ui/ui_atlas.webp';
  static const String uiAtlasManifest = 'assets/images/ui/ui_atlas.json';

  static const String stoneMatchTitle =
      'assets/images/ui/stone_match_title.png';

  /// 타이틀과 일시정지 메뉴의 큰 버튼 판 아틀라스. 2048 한 장에 작은 UI와 함께 들어가지 않아 따로 둔다.
  /// 설정은 tools/atlas/ui_buttons.json.
  static const String uiButtonsAtlas = 'ui/ui_buttons_atlas.webp';
  static const String uiButtonsAtlasManifest =
      'assets/images/ui/ui_buttons_atlas.json';
}
