import 'package:flutter/foundation.dart';

/// GA4로 보낼 이벤트 한 건. 값은 String, int, double이며 bool은 level_end의 success에만 쓴다.
class Ga4Event {
  const Ga4Event(this.name, this.params);

  final String name;
  final Map<String, Object> params;

  @override
  String toString() => 'Ga4Event($name, $params)';
}

/// 내부 이벤트를 PLAN-011 4.3 표의 GA4 이벤트와 허용 파라미터로 바꾸는 순수 함수(전송, 초기화, 환경 판단은 하지 않는다).
///
/// - 보내지 않는 이벤트와 알 수 없는 이벤트는 null이다. session_start, level_clear, round_specials,
///   hyper_swap, speed_bonus_peak, last_hurrah는 예약명이거나 내부 전용이다. ad_reward는 rewarded_ad_result로 바꿔
///   앱 스트림 예약명을 피한다.
/// - 파라미터는 이벤트별 허용 목록에서만 새로 만든다. 입력 params를 통째로 복사하지 않으므로 session_id, event_id,
///   run_id, player_id, device_id, 이름, 실패 사유, 예약 필드가 들어와도 나가지 않는다. round_key는 만들지 않는다.
/// - 문자열은 허용 목록이나 엄격한 형식만 통과한다. 100자를 넘거나 형식이 틀린 값은 잘라 보내지 않고 그 파라미터를 뺀다.
///   숫자는 유한하고 알려진 범위인 값만 통과한다. 이벤트당 파라미터는 [ga4MaxParams]개 이하다.
/// - 타입: level_end.success만 bool이다. 그 밖의 내부 bool(ok, ranked, granted)은 정수 0/1이다.
/// - 필수 값이 없거나 틀린 이벤트(예: post_score의 score, level_end의 reason)는 null이다.
/// - [channel], [appVersion], [schemaVersion]은 있을 때만 app_channel, app_ver, schema_ver로 붙는다.
///   환경(telemetry_env)과 GA4 활성 여부는 송신측이 정한다.
///
/// [attemptSeq]는 로거가 params가 아니라 판 문맥으로 받는 값이라 따로 넘긴다(level_end, stage_continue에만 쓴다).
Ga4Event? mapGa4Event(
  String name,
  Map<String, Object?> params, {
  String? channel,
  String? appVersion,
  int? schemaVersion,
  int? attemptSeq,
}) {
  final out = <String, Object>{};
  final String ga4Name;
  switch (name) {
    case 'round_start':
      final levelName = _levelName(params);
      final mode = _oneOf(params['mode'], _modes);
      if (levelName == null || mode == null) return null;
      ga4Name = 'level_start';
      out['level_name'] = levelName;
      out['mode'] = mode;
      _put(out, 'daily_key', _dateKey(params['daily_key']));
      _put(out, 'exp', _exp(params['exp']));
    case 'round_end':
      final levelName = _levelName(params);
      final reason = _oneOf(params['reason'], _endReasons);
      if (levelName == null || reason == null) return null;
      ga4Name = 'level_end';
      out['level_name'] = levelName;
      out['success'] = reason == 'level_clear';
      out['reason'] = reason;
      _put(out, 'score', _count(params['score']));
      for (final key in _seconds4) {
        _put(out, key, _sec(params[key]));
      }
      _put(out, 'attempt_seq', _count(attemptSeq, max: _maxSeq));
      _put(out, 'exp', _exp(params['exp']));
    case 'stage_continue':
      final level = _count(params['level'], min: 1, max: _maxLevel);
      if (level == null) return null;
      ga4Name = 'stage_continue';
      out['level'] = level;
      _put(out, 'attempt_seq', _count(attemptSeq, max: _maxSeq));
    case 'ranking_submit':
      final score = _count(params['score']);
      if (score == null) return null;
      ga4Name = 'post_score';
      out['score'] = score;
      _put(out, 'level', _count(params['level'], min: 1, max: _maxLevel));
      _put(out, 'mode', _oneOf(params['mode'], _rankingModes));
      _put(out, 'ok', _flag(params['ok']));
      _put(out, 'ranked', _flag(params['ranked']));
      _put(out, 'rank', _count(params['rank'], min: 1, max: _maxRank));
    case 'ad_reward':
      final placement = _oneOf(params['placement'], _placements);
      if (placement == null) return null;
      ga4Name = 'rewarded_ad_result';
      out['placement'] = placement;
      _put(out, 'result', _oneOf(params['result'], _adResults));
      _put(out, 'granted', _flag(params['granted']));
      _put(out, 'outcome', _oneOf(params['outcome'], _adOutcomes));
      _put(out, 'item', _oneOf(params['item'], _items));
    case 'round_summary':
      ga4Name = 'round_summary';
      for (final key in _summaryKeys) {
        _put(out, key, _count(params[key]));
      }
      if (out.isEmpty) return null;
    case 'round_input':
      ga4Name = 'round_input';
      for (final key in _inputKeys) {
        _put(out, key, _count(params[key]));
      }
      _put(
        out,
        'first_success_active_s',
        _sec(params['first_success_active_s']),
      );
      if (out.isEmpty) return null;
    case 'badge_earned':
      final badge = _oneOf(params['badge'], _badges);
      final tier = _count(params['tier'], min: 1, max: _maxTier);
      if (badge == null || tier == null) return null;
      ga4Name = 'unlock_achievement';
      out['achievement_id'] = '${badge}_$tier';
    case 'rank_up':
      final rank = _count(params['rank'], min: 1, max: _maxRank);
      if (rank == null) return null;
      ga4Name = 'level_up';
      out['level'] = rank;
      out['character'] = 'cumulative';
    case 'title_menu_action':
      final action = _oneOf(params['action'], _titleActions);
      if (action == null) return null;
      ga4Name = 'title_menu_action';
      out['action'] = action;
    case 'game_menu_action':
      final action = _oneOf(params['action'], _gameActions);
      if (action == null) return null;
      ga4Name = 'game_menu_action';
      out['action'] = action;
      _put(out, 'mode', _oneOf(params['mode'], _modes));
    case 'player_name_dialog':
      final step = _oneOf(params['step'], _dialogSteps);
      if (step == null) return null;
      ga4Name = 'player_name_dialog';
      out['step'] = step;
      _put(out, 'mode', _oneOf(params['mode'], _modes));
    default:
      return null;
  }
  _put(out, 'app_channel', _oneOf(channel, _channels));
  _put(out, 'app_ver', _version(appVersion));
  _put(out, 'schema_ver', _count(schemaVersion, min: 1, max: 999));
  return ga4Finalize(ga4Name, out);
}

/// 이벤트당 사용자 정의 파라미터 상한(공식 한도 25개보다 보수적인 운영 규칙, PLAN-011 4.1).
const int ga4MaxParams = 20;

/// GA4 값 길이 한도.
const int ga4MaxValueLength = 100;

const int _maxSeq = 1000;
const int _maxLevel = 100000;
const int _maxRank = 1000;
const int _maxTier = 4;
const int _maxCount = 1000000000;
const double _maxSeconds = 1000000;

const Set<String> _modes = {'simple', 'progression', 'timed'};
const Set<String> _rankingModes = {'level', 'time'};
const Set<String> _endReasons = {'level_clear', 'time_up', 'exit', 'restart'};
const Set<String> _placements = {'refill_item', 'continue_stage'};
const Set<String> _adResults = {
  'rewarded',
  'dismissed',
  'failed',
  'unavailable',
};
const Set<String> _adOutcomes = {
  'granted',
  'adNotCompleted',
  'limitReached',
  'rejected',
};
const Set<String> _items = {
  'runeHammer',
  'ancientBomb',
  'thorHammer',
  'hyperCube',
  'prismTransform',
  'fateShuffle',
  'timeSlip',
  'hintPlus',
};
const Set<String> _badges = {
  'bombMaker',
  'starMaker',
  'hyperMaker',
  'supernovaMaker',
  'comboMaster',
  'bigMove',
  'timeScore',
  'levelReach',
  'gemCollector',
  'annihilator',
};
const Set<String> _titleActions = {
  'settings',
  'records',
  'help',
  'mode_simple',
  'mode_progression',
  'mode_timed',
  'ranking',
};
const Set<String> _gameActions = {'pause', 'help', 'ranking'};
const Set<String> _dialogSteps = {'open', 'confirm', 'cancel'};
const Set<String> _channels = {'play', 'appstore', 'onestore', 'intoss', 'web'};
const List<String> _seconds4 = [
  'duration_s',
  'active_s',
  'paused_s',
  'background_s',
];
const List<String> _summaryKeys = [
  'valid_swaps',
  'match_groups',
  'removed_gems',
  'removed_specials',
  'specials_created',
  'specials_activated',
  'hyper_swaps',
  'best_move',
  'max_combo',
];
const List<String> _inputKeys = [
  'invalid_swaps',
  'tap_swaps',
  'drag_swaps',
  'special_taps',
  'hints_used',
  'items_used',
];

/// 예약 이름(웹 예약 이벤트, 앱 예약 이벤트)과 예약 접두사. 보낼 이벤트 이름은 이 목록과 겹치면 안 된다.
const Set<String> _reservedEvents = {
  'session_start',
  'first_visit',
  'first_open',
  'page_view',
  'user_engagement',
  'error',
  'click',
  'scroll',
  'ad_reward',
  'app_update',
};
const List<String> _reservedPrefixes = [
  '_',
  'firebase_',
  'ga_',
  'google_',
  'gtag.',
];

/// 식별자와 개인정보 후보 이름. 어떤 이벤트에서도 파라미터로 나가면 안 된다.
const Set<String> _forbiddenParams = {
  'session_id',
  'event_id',
  'run_id',
  'round_key',
  'player_id',
  'device_id',
  'device_secret',
  'user_id',
  'uid',
  'cid',
  'sid',
  'analytics_id',
  'name',
  'player_name',
  'email',
  'token',
  'failure',
  'event_seq',
  'round_seq',
};

final RegExp _nameRe = RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,39}$');
final RegExp _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _expRe = RegExp(r'^[A-Za-z0-9_:,.\-]{1,64}$');
final RegExp _versionRe = RegExp(r'^[0-9A-Za-z][0-9A-Za-z._+\-]{0,31}$');

/// 마지막 방어선: 이름과 값이 GA4 규칙과 이 앱의 금지 목록을 지키는지 확인하고 상한을 적용한다.
/// 이벤트 이름이 예약명이거나 규칙에 어긋나면 null이다. 금지 이름, 예약 접두사, 100자 초과 문자열,
/// 유한하지 않은 숫자, 지원하지 않는 타입은 그 파라미터만 뺀다. [ga4MaxParams]를 넘으면 앞에서부터 남긴다.
@visibleForTesting
Ga4Event? ga4Finalize(String name, Map<String, Object> params) {
  if (!_nameRe.hasMatch(name) ||
      _reservedEvents.contains(name) ||
      _reservedPrefixes.any(name.startsWith)) {
    return null;
  }
  final safe = <String, Object>{};
  for (final entry in params.entries) {
    if (safe.length >= ga4MaxParams) break;
    final key = entry.key;
    final value = entry.value;
    if (!_nameRe.hasMatch(key) ||
        _forbiddenParams.contains(key) ||
        _reservedPrefixes.any(key.startsWith)) {
      continue;
    }
    final ok = switch (value) {
      String() => value.isNotEmpty && value.length <= ga4MaxValueLength,
      int() => true,
      double() => value.isFinite,
      bool() => name == 'level_end' && key == 'success',
      _ => false,
    };
    if (ok) safe[key] = value;
  }
  return Ga4Event(name, Map.unmodifiable(safe));
}

void _put(Map<String, Object> out, String key, Object? value) {
  if (value != null) out[key] = value;
}

String? _oneOf(Object? value, Set<String> allowed) =>
    value is String && allowed.contains(value) ? value : null;

/// 음이 아닌 정수 또는 정수로 떨어지는 유한한 실수.
int? _count(Object? value, {int min = 0, int max = _maxCount}) {
  final n = switch (value) {
    int() => value,
    double() when value.isFinite && value == value.roundToDouble() =>
      value.toInt(),
    _ => null,
  };
  return n != null && n >= min && n <= max ? n : null;
}

/// 초 단위 시간. 유한한 0 이상 값을 밀리초까지 반올림한다.
double? _sec(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value > _maxSeconds) {
    return null;
  }
  return (value * 1000).round() / 1000;
}

/// 내부 bool을 GA4 맞춤 이벤트용 정수 0/1로 바꾼다. 0/1 정수도 받는다.
int? _flag(Object? value) => switch (value) {
  true => 1,
  false => 0,
  0 => 0,
  1 => 1,
  _ => null,
};

/// YYYY-MM-DD이며 실제 달력에 있는 날짜만(Dart는 2026-13-45 같은 값을 밀어서 받아들이므로 되돌려 비교한다).
String? _dateKey(Object? value) {
  if (value is! String || !_dateRe.hasMatch(value)) return null;
  final y = int.parse(value.substring(0, 4));
  final m = int.parse(value.substring(5, 7));
  final d = int.parse(value.substring(8, 10));
  final date = DateTime.utc(y, m, d);
  return date.year == y && date.month == m && date.day == d ? value : null;
}

String? _exp(Object? value) =>
    value is String && _expRe.hasMatch(value) ? value : null;

String? _version(String? value) =>
    value != null && _versionRe.hasMatch(value) ? value : null;

/// level_name은 모드 이름이고, 진행 모드에 레벨이 있으면 progression_L{level}이다.
String? _levelName(Map<String, Object?> params) {
  final mode = _oneOf(params['mode'], _modes);
  if (mode == null) return null;
  if (mode == 'progression') {
    final level = _count(params['level'], min: 1, max: _maxLevel);
    if (level != null) return 'progression_L$level';
  }
  return mode;
}
