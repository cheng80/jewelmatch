import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/services/ga4_event_mapper.dart';

Ga4Event? _map(String name, Map<String, Object?> params, {int? attemptSeq}) =>
    mapGa4Event(
      name,
      params,
      channel: 'intoss',
      appVersion: '1.0.0+1',
      schemaVersion: 3,
      attemptSeq: attemptSeq,
    );

const _common = {
  'app_channel': 'intoss',
  'app_ver': '1.0.0+1',
  'schema_ver': 3,
};

/// 내부 로거가 예약 필드나 식별자를 params에 실어 보낸 최악의 입력.
const _ids = <String, Object?>{
  'session_id': 'S-SECRET',
  'event_id': 'E-SECRET',
  'run_id': 'R-SECRET',
  'round_seq': 2,
  'attempt_seq': 9,
  'player_id': 'P-SECRET',
  'device_id': 'D-SECRET',
  'device_secret': 'DS-SECRET',
  'user_id': 'U-SECRET',
  'analytics_id': 'A-SECRET',
  'player_name': 'NAME-SECRET',
  'email': 'me@mail.com',
  'round_key': 'abcd1234-2',
  'telemetry_env': 'production',
  'failure': 'FAIL-SECRET',
};

String _dump(Ga4Event e) => '${e.name} ${e.params}';

final _nameRe = RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,39}$');

void main() {
  group('추천 이벤트 매핑', () {
    test('round_start는 level_start', () {
      final e = _map('round_start', {
        'mode': 'timed',
        'daily_key': '2026-09-29',
        'exp': 't1,c7:5',
      })!;
      expect(e.name, 'level_start');
      expect(e.params, {
        'level_name': 'timed',
        'mode': 'timed',
        'daily_key': '2026-09-29',
        'exp': 't1,c7:5',
        ..._common,
      });
    });

    test('round_end는 level_end, success는 bool이고 level_clear만 true', () {
      final params = {
        'mode': 'progression',
        'level': 7,
        'score': 1234,
        'duration_s': 61.23456,
        'active_s': 50.0,
        'system_s': 3.0,
        'paused_s': 8.1,
        'background_s': 0.0,
        'time_gems': 2,
      };
      final clear = _map('round_end', {
        ...params,
        'reason': 'level_clear',
      }, attemptSeq: 1)!;
      expect(clear.name, 'level_end');
      expect(clear.params['success'], true);
      expect(clear.params['success'], isA<bool>());
      expect(clear.params['level_name'], 'progression_L7');
      expect(clear.params['reason'], 'level_clear');
      expect(clear.params['score'], 1234);
      expect(clear.params['duration_s'], 61.235);
      expect(clear.params['attempt_seq'], 1);
      expect(clear.params.containsKey('system_s'), isFalse);
      expect(clear.params.containsKey('time_gems'), isFalse);
      for (final reason in ['time_up', 'exit', 'restart']) {
        final e = _map('round_end', {...params, 'reason': reason})!;
        expect(e.params['success'], false, reason: reason);
        expect(e.params['success'], isA<bool>(), reason: reason);
        expect(e.params.containsKey('attempt_seq'), isFalse);
      }
    });

    test('ranking_submit은 post_score, 내부 bool은 0/1, failure는 보내지 않는다', () {
      final ok = _map('ranking_submit', {
        'mode': 'level',
        'score': 500,
        'ok': true,
        'ranked': true,
        'rank': 3,
      })!;
      expect(ok.name, 'post_score');
      expect(ok.params, {
        'score': 500,
        'mode': 'level',
        'ok': 1,
        'ranked': 1,
        'rank': 3,
        ..._common,
      });
      final fail = _map('ranking_submit', {
        'mode': 'time',
        'score': 10,
        'ok': false,
        'failure': 'FAIL-SECRET',
      })!;
      expect(fail.params['ok'], 0);
      expect(_dump(fail), isNot(contains('FAIL-SECRET')));
      expect(fail.params.containsKey('failure'), isFalse);
    });

    test('badge_earned는 unlock_achievement, rank_up은 level_up', () {
      final badge = _map('badge_earned', {'badge': 'bombMaker', 'tier': 2})!;
      expect(badge.name, 'unlock_achievement');
      expect(badge.params, {'achievement_id': 'bombMaker_2', ..._common});
      final up = _map('rank_up', {'rank': 5})!;
      expect(up.name, 'level_up');
      expect(up.params, {'level': 5, 'character': 'cumulative', ..._common});
    });

    test('ad_reward는 예약명을 피해 rewarded_ad_result, granted는 0/1', () {
      final e = _map('ad_reward', {
        'placement': 'refill_item',
        'result': 'rewarded',
        'granted': true,
        'outcome': 'granted',
        'item': 'hintPlus',
        'level': 4,
      })!;
      expect(e.name, 'rewarded_ad_result');
      expect(e.params, {
        'placement': 'refill_item',
        'result': 'rewarded',
        'granted': 1,
        'outcome': 'granted',
        'item': 'hintPlus',
        ..._common,
      });
      final cont = _map('ad_reward', {
        'placement': 'continue_stage',
        'result': 'dismissed',
        'granted': false,
        'level': 4,
      })!;
      expect(cont.params['granted'], 0);
    });

    test('stage_continue, round_summary, round_input', () {
      final cont = _map('stage_continue', {'level': 8}, attemptSeq: 2)!;
      expect(cont.params, {'level': 8, 'attempt_seq': 2, ..._common});
      final summary = _map('round_summary', {
        'valid_swaps': 30,
        'match_groups': 20,
        'removed_gems': 90,
        'removed_specials': 2,
        'specials_created': 3,
        'specials_activated': 3,
        'hyper_swaps': 1,
        'best_move': 800,
        'max_combo': 6,
        'unknown_stat': 5,
      })!;
      expect(summary.name, 'round_summary');
      expect(summary.params.length, 9 + _common.length);
      expect(summary.params['best_move'], 800);
      expect(summary.params.containsKey('unknown_stat'), isFalse);
      final input = _map('round_input', {
        'invalid_swaps': 4,
        'tap_swaps': 10,
        'drag_swaps': 20,
        'special_taps': 1,
        'hints_used': 0,
        'items_used': 2,
        'first_success_active_s': 3.5,
      })!;
      expect(input.name, 'round_input');
      expect(input.params.length, 7 + _common.length);
      expect(input.params['first_success_active_s'], 3.5);
      // 첫 성공 시각이 없으면(값 생략) 그 필드만 빠진다.
      final noFirst = _map('round_input', {'invalid_swaps': 1})!;
      expect(noFirst.params.containsKey('first_success_active_s'), isFalse);
    });

    test('메뉴 이벤트는 같은 이름과 허용된 action, step, mode만', () {
      expect(_map('title_menu_action', {'action': 'mode_timed'})!.params, {
        'action': 'mode_timed',
        ..._common,
      });
      expect(
        _map('game_menu_action', {'action': 'pause', 'mode': 'simple'})!.params,
        {'action': 'pause', 'mode': 'simple', ..._common},
      );
      expect(
        _map('player_name_dialog', {
          'step': 'confirm',
          'mode': 'timed',
        })!.params,
        {'step': 'confirm', 'mode': 'timed', ..._common},
      );
      expect(
        _map('player_name_dialog', {
          'step': 'open',
        })!.params.containsKey('mode'),
        isFalse,
      );
      // 허용 목록 밖은 이벤트째 버린다(이름 문자열이 action에 섞여 나가지 않는다).
      expect(_map('title_menu_action', {'action': 'NAME-SECRET'}), isNull);
      expect(_map('game_menu_action', {'action': 'mode_simple'}), isNull);
      expect(_map('player_name_dialog', {'step': 'typed'}), isNull);
      final badMode = _map('game_menu_action', {
        'action': 'help',
        'mode': 'NAME-SECRET',
      })!;
      expect(badMode.params.containsKey('mode'), isFalse);
    });
  });

  group('보내지 않는 이벤트', () {
    test('예약명과 내부 전용 이벤트는 null', () {
      for (final name in [
        'session_start',
        'level_clear',
        'round_specials',
        'hyper_swap',
        'speed_bonus_peak',
        'last_hurrah',
        'item_used',
        'unknown_event',
        '',
        'first_open',
        'page_view',
        'error',
        'ad_reward_x',
      ]) {
        expect(
          _map(name, {'mode': 'simple', 'level': 1}),
          isNull,
          reason: name,
        );
      }
    });

    test('어떤 매핑 결과도 GA4 예약 이름이나 접두사를 쓰지 않는다', () {
      final all = <Ga4Event?>[
        _map('round_start', {'mode': 'simple'}),
        _map('round_end', {'mode': 'simple', 'reason': 'exit'}),
        _map('stage_continue', {'level': 1}),
        _map('ranking_submit', {'score': 1}),
        _map('ad_reward', {'placement': 'refill_item'}),
        _map('round_summary', {'valid_swaps': 1}),
        _map('round_input', {'tap_swaps': 1}),
        _map('badge_earned', {'badge': 'bigMove', 'tier': 1}),
        _map('rank_up', {'rank': 2}),
        _map('title_menu_action', {'action': 'help'}),
        _map('game_menu_action', {'action': 'help'}),
        _map('player_name_dialog', {'step': 'open'}),
      ];
      const reserved = {'session_start', 'ad_reward', 'first_open', 'error'};
      for (final e in all) {
        expect(e, isNotNull);
        expect(reserved.contains(e!.name), isFalse, reason: e.name);
        expect(_nameRe.hasMatch(e.name), isTrue);
        for (final key in e.params.keys) {
          expect(_nameRe.hasMatch(key), isTrue);
          expect(key.startsWith('firebase_') || key.startsWith('ga_'), isFalse);
        }
      }
    });
  });

  group('개인정보와 식별자', () {
    test('모든 이벤트에서 식별자와 개인정보 후보가 나가지 않는다', () {
      final inputs = <String, Map<String, Object?>>{
        'round_start': {'mode': 'simple', 'daily_key': '2026-09-29'},
        'round_end': {'mode': 'simple', 'reason': 'exit', 'score': 1},
        'stage_continue': {'level': 3},
        'ranking_submit': {'mode': 'level', 'score': 9, 'ok': false},
        'ad_reward': {'placement': 'continue_stage', 'result': 'failed'},
        'round_summary': {'valid_swaps': 1},
        'round_input': {'tap_swaps': 1},
        'badge_earned': {'badge': 'bigMove', 'tier': 1},
        'rank_up': {'rank': 2},
        'title_menu_action': {'action': 'ranking'},
        'game_menu_action': {'action': 'pause'},
        'player_name_dialog': {'step': 'cancel'},
      };
      const secrets = [
        'S-SECRET',
        'E-SECRET',
        'R-SECRET',
        'P-SECRET',
        'D-SECRET',
        'DS-SECRET',
        'U-SECRET',
        'A-SECRET',
        'NAME-SECRET',
        'me@mail.com',
        'abcd1234',
        'FAIL-SECRET',
      ];
      const banned = {
        'session_id',
        'event_id',
        'run_id',
        'round_seq',
        'player_id',
        'device_id',
        'user_id',
        'analytics_id',
        'round_key',
        'telemetry_env',
        'failure',
        'player_name',
        'email',
      };
      inputs.forEach((name, params) {
        final e = _map(name, {...params, ..._ids})!;
        final text = _dump(e);
        for (final s in secrets) {
          expect(text, isNot(contains(s)), reason: '$name $s');
        }
        expect(
          e.params.keys.toSet().intersection(banned),
          isEmpty,
          reason: name,
        );
        // 로거 예약 필드 attempt_seq는 params가 아니라 인자로만 받는다.
        expect(e.params.containsKey('attempt_seq'), isFalse, reason: name);
      });
    });

    test('채널, 버전, exp 자리로 자유 문자열이 새지 않는다', () {
      final e = mapGa4Event(
        'round_start',
        {'mode': 'simple', 'exp': 'me@mail.com token'},
        channel: 'NAME-SECRET',
        appVersion: 'me@mail.com',
        schemaVersion: 3,
      )!;
      expect(e.params.keys, containsAll(['level_name', 'mode', 'schema_ver']));
      expect(e.params.containsKey('exp'), isFalse);
      expect(e.params.containsKey('app_channel'), isFalse);
      expect(e.params.containsKey('app_ver'), isFalse);
      expect(_dump(e), isNot(contains('mail.com')));
    });

    test('공통 파라미터는 인자가 없으면 붙지 않는다', () {
      final e = mapGa4Event('round_start', {'mode': 'simple'})!;
      expect(e.params, {'level_name': 'simple', 'mode': 'simple'});
    });
  });

  group('제한과 타입', () {
    test('파라미터는 20개 이하, 값은 100자 이하, 이름 규칙 준수', () {
      final e = ga4Finalize('level_end', {
        for (var i = 0; i < 40; i++) 'p$i': i,
      })!;
      expect(e.params.length, ga4MaxParams);
      expect(ga4MaxParams, 20);
      // 100자 초과 문자열은 자르지 않고 그 파라미터를 뺀다. 100자 딱 맞으면 유지한다.
      final long = ga4Finalize('x_event', {
        'a': 'x' * 101,
        'b': 'y' * 100,
        'c': '',
      })!;
      expect(long.params.keys, ['b']);
      expect((long.params['b']! as String).length, 100);
      // 40자를 넘거나 잘못된 파라미터 이름, 예약 접두사, 금지 이름
      final names = ga4Finalize('x_event', {
        'k' * 41: 1,
        '1abc': 1,
        'has space': 1,
        'firebase_x': 1,
        'ga_x': 1,
        '_x': 1,
        'session_id': 'x',
        'user_id': 'x',
        'ok_name': 1,
      })!;
      expect(names.params.keys, ['ok_name']);
    });

    test('이벤트 이름 규칙과 예약 이름은 finalize에서도 막는다', () {
      for (final name in [
        'session_start',
        'ad_reward',
        'first_visit',
        'page_view',
        'firebase_x',
        'ga_x',
        'google_x',
        '_x',
        '1x',
        'a' * 41,
        'has space',
      ]) {
        expect(ga4Finalize(name, {'a': 1}), isNull, reason: name);
      }
      expect(ga4Finalize('a' * 40, {'a': 1}), isNotNull);
    });

    test('bool은 level_end.success만, 숫자는 유한한 값만, 지원 밖 타입은 제거', () {
      final other = ga4Finalize('post_score', {
        'ok': true,
        'n': double.nan,
        'inf': double.infinity,
        'list': [1],
        'v': 1.5,
      })!;
      expect(other.params, {'v': 1.5});
      final end = ga4Finalize('level_end', {'success': true, 'other': false})!;
      expect(end.params, {'success': true});
    });

    test('허용 밖 숫자와 타입은 그 파라미터만 빠지고 필수 값이 없으면 이벤트째 버린다', () {
      final e = _map('round_end', {
        'mode': 'simple',
        'reason': 'time_up',
        'score': -5,
        'duration_s': double.nan,
        'active_s': -1.0,
        'paused_s': '12',
        'background_s': double.infinity,
      })!;
      expect(e.params.containsKey('score'), isFalse);
      for (final key in [
        'duration_s',
        'active_s',
        'paused_s',
        'background_s',
      ]) {
        expect(e.params.containsKey(key), isFalse, reason: key);
      }
      expect(_map('round_end', {'mode': 'simple', 'reason': 'crash'}), isNull);
      expect(_map('round_end', {'mode': 'simple'}), isNull);
      expect(_map('round_end', {'mode': 'weird', 'reason': 'exit'}), isNull);
      expect(_map('round_start', {'mode': 'NAME-SECRET'}), isNull);
      expect(_map('ranking_submit', {'mode': 'level'}), isNull);
      expect(_map('ranking_submit', {'score': 'abc'}), isNull);
      expect(_map('ranking_submit', {'score': double.nan}), isNull);
      expect(_map('stage_continue', {}), isNull);
      expect(_map('stage_continue', {'level': 0}), isNull);
      expect(_map('badge_earned', {'badge': 'x', 'tier': 1}), isNull);
      expect(_map('badge_earned', {'badge': 'bigMove', 'tier': 9}), isNull);
      expect(_map('rank_up', {'rank': 'a'}), isNull);
      expect(_map('ad_reward', {'placement': 'infiniteBanner'}), isNull);
      expect(_map('round_summary', {'unknown': 1}), isNull);
      expect(_map('round_input', {}), isNull);
    });

    test('알려진 숫자만: 정수 값 실수는 정수로, 소수와 과대값은 뺀다', () {
      final e = _map('round_summary', {
        'valid_swaps': 12.0,
        'match_groups': 3.5,
        'removed_gems': 2000000000,
        'best_move': true,
        'max_combo': '4',
      })!;
      expect(e.params['valid_swaps'], 12);
      expect(e.params['valid_swaps'], isA<int>());
      for (final key in [
        'match_groups',
        'removed_gems',
        'best_move',
        'max_combo',
      ]) {
        expect(e.params.containsKey(key), isFalse, reason: key);
      }
    });

    test(
      'bool 계약: level_end.success만 bool, ok/ranked/granted는 0/1, 잘못된 값은 생략',
      () {
        final end = _map('round_end', {
          'mode': 'simple',
          'reason': 'level_clear',
        })!;
        expect(end.params['success'], isA<bool>());
        final post = _map('ranking_submit', {
          'score': 1,
          'ok': 'yes',
          'ranked': 2,
        })!;
        expect(post.params.containsKey('ok'), isFalse);
        expect(post.params.containsKey('ranked'), isFalse);
        final ad = _map('ad_reward', {
          'placement': 'refill_item',
          'granted': 1,
        })!;
        expect(ad.params['granted'], 1);
        // bool 값은 level_end.success 밖 어디에도 없다.
        for (final e in [post, ad, end]) {
          for (final entry in e.params.entries) {
            if (entry.value is bool) {
              expect('${e.name}.${entry.key}', 'level_end.success');
            }
          }
        }
      },
    );

    test('daily_key와 exp는 형식이 맞을 때만, level_name은 진행 모드에서만 레벨을 붙인다', () {
      bool has(Map<String, Object?> p, String key) =>
          _map('round_start', p)!.params.containsKey(key);
      expect(
        has({'mode': 'timed', 'daily_key': '2026-13-45'}, 'daily_key'),
        isFalse,
      );
      expect(
        has({'mode': 'timed', 'daily_key': '2026-02-30'}, 'daily_key'),
        isFalse,
      );
      expect(
        has({'mode': 'timed', 'daily_key': '2028-02-29'}, 'daily_key'),
        isTrue,
      );
      expect(has({'mode': 'timed', 'daily_key': 'abc'}, 'daily_key'), isFalse);
      expect(has({'mode': 'timed', 'exp': 'x' * 65}, 'exp'), isFalse);
      expect(
        _map('round_end', {
          'mode': 'simple',
          'reason': 'exit',
          'level': 5,
        })!.params['level_name'],
        'simple',
      );
      expect(
        _map('round_start', {'mode': 'progression'})!.params['level_name'],
        'progression',
      );
    });

    test('결과 params는 변경할 수 없다', () {
      final e = _map('round_start', {'mode': 'simple'})!;
      expect(() => e.params['x'] = 1, throwsUnsupportedError);
    });
  });
}
