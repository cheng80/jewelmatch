import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/app_config.dart';
import 'package:stonematch/game/gameplay_flags.dart';
import 'package:stonematch/services/backend/supabase_config.dart';
import 'package:stonematch/services/backend/supabase_gateway.dart';
import 'package:stonematch/services/gameplay_config_service.dart';
import 'package:stonematch/utils/storage_helper.dart';

const _config = SupabaseConfig(
  url: 'https://example.supabase.co',
  publishableKey: 'sb_publishable_test',
);

SupabaseGateway _gateway(http.Response Function(http.Request) handler) =>
    SupabaseGateway(
      config: _config,
      client: MockClient((request) async => handler(request)),
    );

http.Response _rows(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

String? _cached() => StorageHelper.read<String>(StorageKeys.gameplayFlags);

void main() {
  String? url;

  setUp(() async {
    url = null;
    GameplayConfigService.urlOverride = () => url;
    GameplayFlags.current = const GameplayFlags();
  });

  Future<void> prefs([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    await StorageHelper.init();
  }

  test('applies cache first, then remote replaces it and is cached', () async {
    await prefs({
      StorageKeys.gameplayFlags: jsonEncode(
        const GameplayFlags(timeGem: true).toJson(),
      ),
    });
    GameplayConfigService.applyCached();
    expect(GameplayFlags.current, const GameplayFlags(timeGem: true));

    Uri? requested;
    await GameplayConfigService.refresh(
      gateway: _gateway((request) {
        requested = request.url;
        return _rows([
          {
            'value': {'multiplier_gem': true, 'seventh_color_from_level': 10},
          },
        ]);
      }),
    );
    expect(requested!.path, '/rest/v1/app_config');
    expect(requested!.queryParameters, {
      'key': 'eq.gameplay',
      'select': 'value',
    });
    const remote = GameplayFlags(
      multiplierGem: true,
      seventhColorFromLevel: 10,
    );
    expect(GameplayFlags.current, remote);
    expect(jsonDecode(_cached()!), remote.toJson());
  });

  test('remote failure keeps cached value', () async {
    await prefs({
      StorageKeys.gameplayFlags: jsonEncode(
        const GameplayFlags(timeRewardT1: true).toJson(),
      ),
    });
    GameplayConfigService.applyCached();
    for (final response in [
      _rows({'message': 'boom'}, 500),
      _rows(<Object>[]),
      _rows([
        {'value': 'not a map'},
      ]),
    ]) {
      await GameplayConfigService.refresh(gateway: _gateway((_) => response));
      expect(GameplayFlags.current, const GameplayFlags(timeRewardT1: true));
    }
    await GameplayConfigService.refresh(
      gateway: _gateway((_) => throw Exception('offline')),
    );
    expect(GameplayFlags.current, const GameplayFlags(timeRewardT1: true));
    expect(
      jsonDecode(_cached()!),
      const GameplayFlags(timeRewardT1: true).toJson(),
    );
  });

  test('unconfigured build does not call network and keeps defaults', () async {
    await prefs();
    GameplayConfigService.applyCached();
    await GameplayConfigService.refresh(
      gateway: SupabaseGateway(
        config: const SupabaseConfig(url: '', publishableKey: ''),
        client: MockClient((_) async => fail('no request expected')),
      ),
    );
    expect(GameplayFlags.current, const GameplayFlags());
    expect(_cached(), isNull);
  });

  test('broken cache JSON falls back to defaults', () async {
    for (final raw in ['{not json', '[1,2]', '"text"']) {
      await prefs({StorageKeys.gameplayFlags: raw});
      GameplayFlags.current = const GameplayFlags(timeGem: true);
      GameplayConfigService.applyCached();
      expect(GameplayFlags.current, const GameplayFlags(), reason: raw);
    }
  });

  test(
    'URL override wins over cache and late remote, and is not cached',
    () async {
      await prefs({
        StorageKeys.gameplayFlags: jsonEncode(
          const GameplayFlags(timeGem: true).toJson(),
        ),
      });
      url = '-tg,nolhc';
      GameplayConfigService.applyCached();
      expect(
        GameplayFlags.current,
        const GameplayFlags(lastHurrahComboMultiplier: false),
      );

      await GameplayConfigService.refresh(
        gateway: _gateway(
          (_) => _rows([
            {
              'value': {'time_gem': true, 'multiplier_gem': true},
            },
          ]),
        ),
      );
      expect(
        GameplayFlags.current,
        const GameplayFlags(
          multiplierGem: true,
          lastHurrahComboMultiplier: false,
        ),
      );
      expect(
        jsonDecode(_cached()!),
        const GameplayFlags(timeGem: true, multiplierGem: true).toJson(),
      );
    },
  );
}
