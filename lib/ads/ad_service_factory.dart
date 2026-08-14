import '../app_config.dart';
import 'ad_service.dart';
import 'fake_ad_service.dart';
import 'intoss_ad_service_stub.dart'
    if (dart.library.js_interop) 'intoss_ad_service_web.dart';
import 'unsupported_ad_service.dart';

AdService createAdService() => switch (AppConfig.intossAdMode) {
  IntossAdMode.mock => FakeAdService(),
  IntossAdMode.test || IntossAdMode.production => createIntossAdService(),
  IntossAdMode.disabled => UnsupportedAdService(),
};
