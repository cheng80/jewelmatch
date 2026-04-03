/// 에셋 경로 상수.
/// 하드코딩을 피하고 한곳에서 관리한다.
class AssetPaths {
  AssetPaths._();

  /// 효과음 경로. FlameAudio.play()에는 assets/audio/ 이후 상대 경로를 전달한다.
  static const String sfxTimeTic = 'sfx/TimeTic.mp3';
  static const String sfxStart = 'sfx/Start.mp3';
  static const String sfxCollect = 'sfx/Collect.mp3';
  static const String sfxFail = 'sfx/Fail.mp3';
  static const String sfxBtnSnd = 'sfx/BtnSnd.mp3';
  static const String sfxClear = 'sfx/Clear.mp3';

  /// BGM 경로. FlameAudio.bgm에는 assets/audio/ 이후 상대 경로를 전달한다.
  static const String bgmMenu = 'music/Menu_BGM.wav';
  static const String bgmMain = 'music/Main_BGM.wav';

  /// 폰트 family 이름 (pubspec.yaml에 등록된 이름과 동일)
  static const String fontAngduIpsul140 = 'HUAngduIpsul140';

  /// 7열×256px 보석 스프라이트 시트 (색은 코드에서 열 인덱스로 매핑)
  static const String juwelSpriteSheet = 'sprites/Juwel.png';
}
