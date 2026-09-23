import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/app_config.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_models.dart';
import 'package:stonematch/services/records/player_records.dart';
import 'package:stonematch/services/records/records_store.dart';
import 'package:stonematch/utils/storage_helper.dart';
import 'package:stonematch/views/records_view.dart';

Future<void> _resetStorage([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  await StorageHelper.init();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CumulativeRank', () {
    test('threshold boundaries', () {
      expect(CumulativeRank.thresholdFor(1), 0);
      expect(CumulativeRank.thresholdFor(2), 15000);
      expect(CumulativeRank.thresholdFor(50), 12495000);
      expect(CumulativeRank.rankForScore(0), 1);
      expect(CumulativeRank.rankForScore(14999), 1);
      expect(CumulativeRank.rankForScore(15000), 2);
      expect(CumulativeRank.rankForScore(39999), 2);
      expect(CumulativeRank.rankForScore(40000), 3);
      expect(CumulativeRank.rankForScore(12494999), 49);
      expect(CumulativeRank.rankForScore(12495000), 50);
      expect(CumulativeRank.rankForScore(999999999), 50);
      expect(CumulativeRank.pointsToNext(14000), 1000);
      expect(CumulativeRank.pointsToNext(12495000), isNull);
    });

    test('rank matches threshold for every step', () {
      for (var rank = 1; rank <= CumulativeRank.maxRank; rank++) {
        final t = CumulativeRank.thresholdFor(rank);
        expect(CumulativeRank.rankForScore(t), rank);
        if (rank > 1) expect(CumulativeRank.rankForScore(t - 1), rank - 1);
      }
    });
  });

  group('RecordBadge', () {
    test('tier boundaries', () {
      const badge = RecordBadge.comboMaster;
      expect(badge.tierFor(2), 0);
      expect(badge.tierFor(3), 1);
      expect(badge.tierFor(4), 1);
      expect(badge.tierFor(5), 2);
      expect(badge.tierFor(10), 4);
      expect(badge.tierFor(99), 4);
      expect(badge.nextThreshold(0), 3);
      expect(badge.nextThreshold(4), isNull);
    });

    test('annihilator works with zero hyper swaps', () {
      final records = PlayerRecords();
      expect(records.badgeTier(RecordBadge.annihilator), 0);
      records.apply(
        const RoundRecord(mode: JewelGameMode.timed, hyperSwaps: 1),
      );
      expect(records.badgeTier(RecordBadge.annihilator), 1);
    });

    test('first supernova earns bronze', () {
      final records = PlayerRecords()
        ..apply(
          const RoundRecord(
            mode: JewelGameMode.simple,
            specialsCreated: {GemKind.supernova: 1},
          ),
        );
      expect(records.badgeTier(RecordBadge.supernovaMaker), 1);
    });
  });

  group('RoundRecord.minus', () {
    test('subtracts counters only for the same stage', () {
      const first = RoundRecord(
        mode: JewelGameMode.progression,
        score: 5000,
        removedGems: 40,
        specialsCreated: {GemKind.bomb: 2},
      );
      const second = RoundRecord(
        mode: JewelGameMode.progression,
        score: 9000,
        removedGems: 70,
        specialsCreated: {GemKind.bomb: 3},
      );
      final delta = second.minus(first, sameScore: true, sameStats: true);
      expect(delta.score, 4000);
      expect(delta.removedGems, 30);
      expect(delta.specialsCreated[GemKind.bomb], 1);
      expect(
        second.minus(first, sameScore: false, sameStats: false).score,
        9000,
      );
    });
  });

  group('RecordsStore', () {
    test('save and load round trip', () async {
      await _resetStorage();
      final update = RecordsStore.apply(
        const RoundRecord(
          mode: JewelGameMode.timed,
          score: 16000,
          removedGems: 120,
          specialsCreated: {GemKind.bomb: 10, GemKind.star: 1},
          maxCombo: 4,
          bestMoveScore: 3200,
        ),
      );
      expect(update.rankedUp, isTrue);
      expect(update.rankAfter, 2);
      expect(
        update.earnedBadges.map((e) => e.badge),
        containsAll([
          RecordBadge.bombMaker,
          RecordBadge.comboMaster,
          RecordBadge.bigMove,
          RecordBadge.timeScore,
        ]),
      );

      final loaded = RecordsStore.load();
      expect(loaded.totalScore, 16000);
      expect(loaded.bestScoreByMode[JewelGameMode.timed], 16000);
      expect(loaded.specialCount(GemKind.bomb), 10);
      expect(loaded.longestCombo, 4);
      expect(loaded.bestMoveScore, 3200);
      expect(loaded.badgeTiers[RecordBadge.bombMaker], 1);

      final again = RecordsStore.apply(
        const RoundRecord(mode: JewelGameMode.simple, score: 100),
      );
      expect(again.isEmpty, isTrue);
      expect(RecordsStore.load().totalScore, 16100);
    });

    for (final raw in [
      'not json',
      '[1, 2]',
      '{"v": 99, "totalScore": 5}',
      '{"totalScore": 5}',
    ]) {
      test('corrupted value resets: $raw', () async {
        await _resetStorage({StorageKeys.playerRecords: raw});
        final records = RecordsStore.load();
        expect(records.totalScore, 0);
        final saved = jsonDecode(
          StorageHelper.read<String>(StorageKeys.playerRecords)!,
        );
        expect(saved['v'], PlayerRecords.schemaVersion);
      });
    }

    test('bad field values read as zero', () async {
      await _resetStorage({
        StorageKeys.playerRecords: jsonEncode({
          'v': 1,
          'totalScore': 'abc',
          'longestCombo': -3,
          'specialsCreated': {'bomb': 4, 'unknown': 9},
          'badges': {'bombMaker': 99},
        }),
      });
      final records = RecordsStore.load();
      expect(records.totalScore, 0);
      expect(records.longestCombo, 0);
      expect(records.specialCount(GemKind.bomb), 4);
      expect(records.badgeTiers[RecordBadge.bombMaker], RecordBadge.maxTier);
    });
  });

  test('game commit twice in one stage counts only the new part', () async {
    await _resetStorage();
    final game = MatchBoardGame(gameMode: JewelGameMode.progression);
    game.board.score = 5000;
    game.board.stats.recordGemRemoved(GemKind.normal);
    game.commitRecords(level: 2);
    game.board.score = 9000;
    game.board.stats.recordGemRemoved(GemKind.normal);
    game.commitRecords(level: 2);
    final records = RecordsStore.load();
    expect(records.totalScore, 9000);
    expect(records.totalRemovedGems, 2);
    expect(records.bestLevel, 2);
  });

  // R-6: 재반영 때 모드별 최고 점수는 차감 전 판 점수로 계산한다.
  test('best score by mode uses the full stage score on re-commit', () async {
    await _resetStorage();
    final game = MatchBoardGame(gameMode: JewelGameMode.progression);
    game.board.score = 6000;
    game.commitRecords(level: 1);
    game.board.score = 7500;
    game.commitRecords(level: 2);
    final records = RecordsStore.load();
    expect(records.totalScore, 7500);
    expect(records.bestScoreByMode[JewelGameMode.progression], 7500);
  });

  group('MatchBoardGameStats move score', () {
    test('keeps the best finished move', () {
      final stats = MatchBoardGameStats()
        ..recordMoveScore(300)
        ..recordMoveScore(600)
        ..finishMove()
        ..recordMoveScore(500)
        ..finishMove();
      expect(stats.bestMoveScore, 900);
    });
  });

  testWidgets('records notice shows rank up and badge lines', (tester) async {
    await _pumpLocalized(
      tester,
      const Locale('ko'),
      const Scaffold(
        body: RecordsUpdateNotice(
          update: RecordsUpdate(
            rankBefore: 1,
            rankAfter: 2,
            earnedBadges: [
              (badge: RecordBadge.bombMaker, tier: 1),
              (badge: RecordBadge.comboMaster, tier: 2),
            ],
          ),
        ),
      ),
    );
    expect(find.text('랭크 2 달성!'), findsOneWidget);
    expect(find.text('배지 획득: 폭탄 장인 (동)'), findsOneWidget);
    // 결과 카드가 넘치지 않도록 기본 두 줄까지만 보인다.
    expect(find.textContaining('연쇄의 달인'), findsNothing);
  });

  testWidgets('records view does not overflow on 320px with 1.25x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _resetStorage();
    RecordsStore.apply(
      const RoundRecord(
        mode: JewelGameMode.timed,
        score: 123456789,
        removedGems: 9876543,
        specialsCreated: {GemKind.bomb: 123456, GemKind.supernova: 3},
        maxCombo: 12,
        bestMoveScore: 987654,
      ),
    );

    for (final locale in _locales) {
      await _pumpLocalized(
        tester,
        locale,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.25)),
            child: const RecordsView(),
          ),
        ),
      );
      expect(find.byType(Scrollable), findsWidgets, reason: '$locale');
      expect(find.textContaining('50'), findsWidgets, reason: '$locale');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });
}

const List<Locale> _locales = [
  Locale('ko'),
  Locale('en'),
  Locale('ja'),
  Locale('zh', 'CN'),
  Locale('zh', 'TW'),
];

Future<void> _pumpLocalized(
  WidgetTester tester,
  Locale locale,
  Widget home,
) async {
  // 앞 테스트의 가짜 시간 영역에서 캐시된 번역 로드가 끝나지 않는 것을 막는다.
  rootBundle.clear();
  await tester.pumpWidget(
    EasyLocalization(
      key: ValueKey(locale),
      supportedLocales: _locales,
      path: 'assets/translations',
      saveLocale: false,
      fallbackLocale: const Locale('ko'),
      startLocale: locale,
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: home,
        ),
      ),
    ),
  );
  // 번역 파일은 실제 비동기로 읽힌다. 화면이 채워질 때까지 기다린다.
  for (var i = 0; i < 20 && find.byType(Text).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
