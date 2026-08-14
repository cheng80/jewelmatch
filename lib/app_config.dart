/// 출시 채널. 빌드할 때 `--dart-define=STORE_CHANNEL=<채널>`로 선택한다.
enum StoreChannel { appstore, play, onestore, intoss }

/// Apps in Toss 광고 실행 환경.
enum IntossAdMode { disabled, mock, test, production }

/// 앱 전반에서 사용하는 상수 모음.
/// private 생성자(_)로 인스턴스 생성을 막고, static 상수만 제공한다.
class AppConfig {
  AppConfig._();

  static const String _storeChannelName = String.fromEnvironment(
    'STORE_CHANNEL',
    defaultValue: 'play',
  );

  static StoreChannel get storeChannel =>
      StoreChannel.values.byName(_storeChannelName);

  static const String _intossAdModeName = String.fromEnvironment(
    'INTOSS_AD_MODE',
    defaultValue: 'disabled',
  );

  static IntossAdMode get intossAdMode =>
      IntossAdMode.values.byName(_intossAdModeName);

  static const String _productionRewardedAdGroupId = String.fromEnvironment(
    'INTOSS_REWARDED_AD_GROUP_ID',
  );
  static const String _productionBannerAdGroupId = String.fromEnvironment(
    'INTOSS_BANNER_AD_GROUP_ID',
  );

  static String get intossRewardedAdGroupId => switch (intossAdMode) {
    IntossAdMode.test => 'ait-ad-test-rewarded-id',
    IntossAdMode.production => _productionRewardedAdGroupId,
    IntossAdMode.disabled || IntossAdMode.mock => '',
  };

  static String get intossBannerAdGroupId => switch (intossAdMode) {
    IntossAdMode.test => 'ait-ad-test-banner-id',
    IntossAdMode.production => _productionBannerAdGroupId,
    IntossAdMode.disabled || IntossAdMode.mock => '',
  };

  /// 잘못된 STORE_CHANNEL 값은 앱 시작 전에 실패시킨다.
  static void validateStoreChannel() {
    storeChannel;
    intossAdMode;
    if (intossAdMode != IntossAdMode.disabled &&
        storeChannel != StoreChannel.intoss) {
      throw StateError('INTOSS_AD_MODE requires STORE_CHANNEL=intoss');
    }
    if (intossAdMode == IntossAdMode.production &&
        (intossRewardedAdGroupId.isEmpty || intossBannerAdGroupId.isEmpty)) {
      throw StateError('Apps in Toss production ad group IDs are required');
    }
  }

  /// iOS/MacOS: App Store Connect > General > App Information > Apple ID. 출시 시 설정.
  static const String appStoreId = '';

  static const String appTitle = 'Stone Match';
  static const String gameTitle = 'Stone';
  static const String gameTitleSub = 'Match';
  static const String gameSubtitle = '같은 보석을 모아보세요!';
  static const bool debugLog = false;
}

/// 로컬 저장소(shared_preferences) 키 상수.
class StorageKeys {
  StorageKeys._();

  static const String bgmVolume = 'bgm_volume';
  static const String sfxVolume = 'sfx_volume';
  static const String bgmMuted = 'bgm_muted';
  static const String sfxMuted = 'sfx_muted';
  static const String keepScreenOn = 'keep_screen_on';
  static const String showFps = 'show_fps';
  static const String bestScorePrefix = 'best_score_mode_';

  /// 이전 단일 키(심플 베스트 마이그레이션용).
  static const String bestMatchScore = 'best_match_score';
  static const String bestMatchSimple = 'best_match_simple';
  static const String bestMatchProgression = 'best_match_progression';
  static const String bestMatchProgressionLevel =
      'best_match_progression_level';
  static const String bestMatchTimed = 'best_match_timed';

  /// 타임 어택 랭킹용 플레이어 이름 (아케이드). 첫 진입 시 기본 'GUEST'.
  static const String playerName = 'player_name';
  static const String firstLaunchDate = 'first_launch_date';
  static const String reviewRequestedAfterFirstClear =
      'review_requested_after_first_clear';
  static const String reviewRequestedOnTitle = 'review_requested_on_title';
}

/// 인앱 리뷰: TitleView에서 일정 기간(일) 경과 후 requestReview 호출.
const int reviewDaysAfterFirstLaunch = 3;

/// GoRouter에서 사용할 경로 상수.
/// 라우트 경로를 한곳에서 관리하여 오타를 방지한다.
class RoutePaths {
  RoutePaths._();

  static const String title = '/';
  static const String game = '/game';
  static const String setting = '/setting';
}
