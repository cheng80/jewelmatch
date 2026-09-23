import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../app_config.dart';
import '../../utils/storage_helper.dart';
import '../event_logger.dart';
import 'player_records.dart';

/// 로컬 누적 기록 저장소. 서버를 쓰지 않는다.
///
/// 손상된 저장값은 빈 기록으로 초기화하고 예외를 밖으로 내보내지 않는다.
class RecordsStore {
  RecordsStore._();

  static PlayerRecords load() {
    try {
      final raw = StorageHelper.read<String>(StorageKeys.playerRecords);
      if (raw == null) return PlayerRecords();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Not a JSON object');
      return PlayerRecords.fromJson(decoded.cast<String, Object?>());
    } catch (error) {
      debugPrint('[Records] reset corrupted records: $error');
      _save(PlayerRecords());
      return PlayerRecords();
    }
  }

  /// 한 판의 값을 반영하고 새 랭크와 새 배지를 돌려준다.
  static RecordsUpdate apply(RoundRecord round) {
    try {
      final records = load();
      final rankBefore = records.rank;
      final tiersBefore = {
        for (final badge in RecordBadge.values) badge: records.badgeTier(badge),
      };
      records.apply(round);
      final earned = <({RecordBadge badge, int tier})>[];
      for (final badge in RecordBadge.values) {
        final tier = records.badgeTier(badge);
        if (tier > 0) records.badgeTiers[badge] = tier;
        if (tier > tiersBefore[badge]!) {
          earned.add((badge: badge, tier: tier));
          EventLogger.instance.log('badge_earned', {
            'badge': badge.name,
            'tier': tier,
          });
        }
      }
      final update = RecordsUpdate(
        rankBefore: rankBefore,
        rankAfter: records.rank,
        earnedBadges: earned,
      );
      if (update.rankedUp) {
        EventLogger.instance.log('rank_up', {'rank': update.rankAfter});
      }
      _save(records);
      return update;
    } catch (error) {
      debugPrint('[Records] apply failed: $error');
      return const RecordsUpdate(rankBefore: 1, rankAfter: 1);
    }
  }

  static void _save(PlayerRecords records) {
    try {
      unawaited(
        StorageHelper.write(
          StorageKeys.playerRecords,
          jsonEncode(records.toJson()),
        ).catchError((Object error) {
          debugPrint('[Records] save failed: $error');
        }),
      );
    } catch (error) {
      debugPrint('[Records] save failed: $error');
    }
  }
}
