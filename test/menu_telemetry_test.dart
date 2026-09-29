import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/app_config.dart' show RoutePaths;
import 'package:stonematch/resources/texture_atlas.dart';
import 'package:stonematch/services/backend/supabase_config.dart';
import 'package:stonematch/services/backend/supabase_gateway.dart';
import 'package:stonematch/services/event_logger.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/services/play_event_context.dart';
import 'package:stonematch/utils/storage_helper.dart';
import 'package:stonematch/views/title/player_name_dialog.dart';
import 'package:stonematch/views/title/title_icon_button.dart';
import 'package:stonematch/views/title/title_round_button.dart';
import 'package:stonematch/views/title_view.dart';

/// 표본 정책은 EventLogger 테스트가 맡는다. 여기서는 제목 화면이 무엇을 보고하는지만 본다.
class _RecordingLogger extends EventLogger {
  _RecordingLogger()
    : super(
        gateway: SupabaseGateway(
          config: const SupabaseConfig(url: '', publishableKey: ''),
        ),
      );

  final calls = <({String name, Map<String, Object?> params})>[];

  @override
  void logBehavior(
    String name,
    Map<String, Object?> params, {
    PlayEventContext? context,
  }) {
    calls.add((name: name, params: Map.of(params)));
  }
}

/// 번역 파일을 읽지 않는다. 문구는 키 그대로 나오므로 테스트는 키로 찾는다.
class _KeyLoader extends AssetLoader {
  const _KeyLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => {};
}

Widget _app(Widget Function(BuildContext) home, {GoRouter? router}) =>
    EasyLocalization(
      supportedLocales: const [Locale('ko')],
      path: 'unused',
      assetLoader: const _KeyLoader(),
      saveLocale: false,
      fallbackLocale: const Locale('ko'),
      startLocale: const Locale('ko'),
      child: Builder(
        builder: (context) => router == null
            ? MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: Builder(builder: home),
              )
            : MaterialApp.router(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                routerConfig: router,
              ),
      ),
    );

/// 번역 파일은 실제 비동기로 읽혀서 pump만으로는 다음 테스트에서 빌드가 늦다. 조건이 될 때까지 기다린다.
Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    // 아틀라스 로딩 결과가 테스트 사이에 캐시되므로, 가짜 시계 밖에서 한 번 올려 두어야 모든 테스트에서 제목이 뜬다.
    await TextureAtlas.precacheUi();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    await StorageHelper.erase();
    GameSettings.playerName = 'GUEST';
    // 소리는 플랫폼 플러그인이 필요하므로 끈다.
    GameSettings.bgmMuted = true;
    GameSettings.sfxMuted = true;
    for (final name in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    PackageInfo.setMockInitialValues(
      appName: 'stonematch',
      packageName: 'test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  group('이름 입력창', () {
    Future<_RecordingLogger> open(
      WidgetTester tester,
      void Function(String?) onResult, {
      String? mode = 'timed',
    }) async {
      final logger = _RecordingLogger();
      await tester.pumpWidget(
        _app(
          (context) => TextButton(
            onPressed: () async => onResult(
              await showPlayerNameDialog(context, mode: mode, logger: logger),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await _until(tester, find.text('open'));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return logger;
    }

    testWidgets('열림과 확인만 기록하고 이름 값은 담지 않는다', (tester) async {
      String? result;
      final logger = await open(tester, (v) => result = v);
      await tester.enterText(find.byType(TextField), 'SECRET_NAME');
      await tester.tap(find.text('startGame'));
      await tester.pumpAndSettle();

      expect(result, 'SECRET_NAME');
      expect(logger.calls.map((c) => c.name).toSet(), {'player_name_dialog'});
      expect(logger.calls.map((c) => c.params), [
        {'step': 'open', 'mode': 'timed'},
        {'step': 'confirm', 'mode': 'timed'},
      ]);
      expect(logger.calls.toString(), isNot(contains('SECRET_NAME')));
    });

    testWidgets('취소 버튼은 cancel을 기록하고 이름을 바꾸지 않는다', (tester) async {
      String? result = 'unset';
      final logger = await open(tester, (v) => result = v);
      await tester.enterText(find.byType(TextField), 'SECRET_NAME');
      await tester.tap(find.text('cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(GameSettings.playerName, 'GUEST');
      expect(logger.calls.map((c) => c.params['step']), ['open', 'cancel']);
    });

    testWidgets('바깥을 눌러 닫아도 cancel로 기록한다', (tester) async {
      String? result = 'unset';
      final logger = await open(tester, (v) => result = v);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(logger.calls.map((c) => c.params['step']), ['open', 'cancel']);
    });

    testWidgets('키보드 제출도 confirm이며 빈 입력은 기존처럼 GUEST', (tester) async {
      String? result;
      final logger = await open(tester, (v) => result = v);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(result, 'GUEST');
      expect(logger.calls.map((c) => c.params['step']), ['open', 'confirm']);
    });

    testWidgets('mode를 안 주면 mode 필드를 붙이지 않는다', (tester) async {
      final logger = await open(tester, (_) {}, mode: null);
      expect(logger.calls.single.params, {'step': 'open'});
    });
  });

  group('제목 화면 메뉴', () {
    late _RecordingLogger logger;
    late List<String> visited;

    Future<void> pumpTitle(WidgetTester tester) async {
      // 제목 화면의 BGM 정지가 만드는 audioplayers 이벤트 채널은 플러그인이 없어 실패한다. 소리 검증이 아니므로 그 오류만 넘긴다.
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        final e = details.exception;
        if (e is MissingPluginException && '$e'.contains('audioplayers')) {
          return;
        }
        previous?.call(details);
      };
      addTearDown(() => FlutterError.onError = previous);
      logger = _RecordingLogger();
      visited = [];
      GoRoute stub(String path) => GoRoute(
        path: path,
        builder: (_, state) {
          visited.add(state.uri.toString());
          return Scaffold(body: Text('stub $path'));
        },
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => TitleView(eventLogger: logger),
          ),
          stub(RoutePaths.setting),
          stub(RoutePaths.records),
          stub(RoutePaths.game),
        ],
      );
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app((_) => const SizedBox(), router: router));
      // 이미지 디코딩은 실제 비동기라 runAsync에서 기다린다.
      await _until(tester, find.byType(TitleRoundButton));
      await tester.pump(const Duration(seconds: 3));
    }

    List<Object?> actions() => logger.calls
        .where((c) => c.name == 'title_menu_action')
        .map((c) => c.params['action'])
        .toList();

    testWidgets('화면을 그리기만 해서는 기록하지 않는다', (tester) async {
      await pumpTitle(tester);
      expect(find.byType(TitleRoundButton), findsNWidgets(4));
      await tester.pump(const Duration(seconds: 3));
      expect(logger.calls, isEmpty);
    });

    testWidgets('설정과 기록 버튼은 실제 경로로 이동하며 기록한다', (tester) async {
      await pumpTitle(tester);
      await tester.tap(find.byType(TitleIconButton).at(0));
      await tester.pumpAndSettle();
      expect(visited, [RoutePaths.setting]);
      expect(actions(), ['settings']);
    });

    testWidgets('기록 버튼', (tester) async {
      await pumpTitle(tester);
      await tester.tap(find.byType(TitleIconButton).at(1));
      await tester.pumpAndSettle();
      expect(visited, [RoutePaths.records]);
      expect(actions(), ['records']);
    });

    testWidgets('도움말 버튼은 도움말을 열고 help를 기록한다', (tester) async {
      await pumpTitle(tester);
      await tester.tap(find.byType(TitleIconButton).at(2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(actions(), ['help']);
      expect(visited, isEmpty);
    });

    testWidgets('심플 모드는 바로 게임 경로로 간다', (tester) async {
      await pumpTitle(tester);
      await tester.tap(find.byType(TitleRoundButton).at(0));
      await tester.pumpAndSettle();
      expect(visited.single, startsWith('${RoutePaths.game}?mode=simple'));
      expect(actions(), ['mode_simple']);
      expect(logger.calls.length, 1);
    });

    testWidgets('진행 모드 확인은 이름 입력을 거쳐 게임 경로로 간다', (tester) async {
      await pumpTitle(tester);
      await tester.tap(find.byType(TitleRoundButton).at(1));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'SECRET_NAME');
      await tester.tap(find.text('startGame'));
      await tester.pumpAndSettle();

      expect(GameSettings.playerName, 'SECRET_NAME');
      expect(visited.single, startsWith('${RoutePaths.game}?mode=progression'));
      expect(logger.calls.map((c) => [c.name, c.params]).toList(), [
        [
          'title_menu_action',
          {'action': 'mode_progression'},
        ],
        [
          'player_name_dialog',
          {'step': 'open', 'mode': 'progression'},
        ],
        [
          'player_name_dialog',
          {'step': 'confirm', 'mode': 'progression'},
        ],
      ]);
      expect(logger.calls.toString(), isNot(contains('SECRET_NAME')));
    });

    testWidgets('타임 모드 취소는 게임 경로로 가지 않는다', (tester) async {
      await pumpTitle(tester);
      await tester.tap(find.byType(TitleRoundButton).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cancel'));
      await tester.pumpAndSettle();

      expect(visited, isEmpty);
      expect(find.byType(TitleRoundButton), findsNWidgets(4));
      expect(logger.calls.map((c) => [c.name, c.params]).toList(), [
        [
          'title_menu_action',
          {'action': 'mode_timed'},
        ],
        [
          'player_name_dialog',
          {'step': 'open', 'mode': 'timed'},
        ],
        [
          'player_name_dialog',
          {'step': 'cancel', 'mode': 'timed'},
        ],
      ]);
    });

    testWidgets('랭킹 버튼은 팝업을 열고 ranking을 기록한다', (tester) async {
      await pumpTitle(tester);
      await tester.tap(find.byType(TitleRoundButton).at(3));
      await tester.pump(const Duration(milliseconds: 500));
      expect(actions(), ['ranking']);
      expect(visited, isEmpty);
    });
  });
}
