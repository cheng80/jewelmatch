/// 에셋 경로 상수.
/// 하드코딩을 피하고 한곳에서 관리한다.
class AssetPaths {
  AssetPaths._();

  /// 효과음 경로. FlameAudio.play()에는 assets/audio/ 이후 상대 경로를 전달한다.
  static const String sfxTimeTic = 'sfx/TimeTic.mp3';
  static const String sfxStart = 'sfx/Start.mp3';
  static const String sfxCollect = 'sfx/Collect.mp3';
  static const String sfxFail = 'sfx/Fail.mp3';
  /// 클리어 등에 사용할 수 있는 SFX (`assets/audio/sfx/Clear.mp3`).
  static const String sfxClear = 'sfx/Clear.mp3';
  static const String sfxBtnSnd = 'sfx/BtnSnd.mp3';

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
  static const String fontAngduIpsul140 = 'HUAngduIpsul140';

  /// 7열×256px 보석 스프라이트 시트 (색은 코드에서 열 인덱스로 매핑)
  static const String juwelSpriteSheet = 'sprites/Juwel.png';
}
