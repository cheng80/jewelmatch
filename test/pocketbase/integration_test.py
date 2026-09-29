"""Real local PocketBase 0.39.7 tests. No external services or stored credentials.
Run: python3 -B -m unittest discover -s test/pocketbase -p '*_test.py' -v
POCKETBASE_BIN may select another local copy of exactly 0.39.7.
"""
import base64
import concurrent.futures
import datetime as dt
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
import urllib.request
import uuid

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
BIN = Path(os.environ.get('POCKETBASE_BIN', ROOT / 'tmp/pocketbase-migration-20260929/runtime/pocketbase')).resolve()
SCRATCH = ROOT / 'tmp/pocketbase-migration-20260929/server'
UTC = dt.timezone.utc
KST = dt.timezone(dt.timedelta(hours=9))
FOLLOWUP = '1790800000_stone_match_event_dedupe_metrics.js'


def iso(value=None):
    return (value or dt.datetime.now(UTC)).isoformat(timespec='microseconds').replace('+00:00', 'Z')


def kst_day(offset):
    return (dt.datetime.now(KST) + dt.timedelta(days=offset)).date()


def at(day, hour=12, minute=0, second=0, micro=0):
    return iso(dt.datetime(day.year, day.month, day.day, hour, minute, second, micro, tzinfo=KST).astimezone(UTC))


class PocketBaseIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if '0.39.7' not in subprocess.check_output([str(BIN), '--version'], text=True):
            raise RuntimeError('PocketBase 0.39.7 required')
        SCRATCH.mkdir(parents=True, exist_ok=True)
        cls.work = Path(tempfile.mkdtemp(prefix='integration-', dir=SCRATCH))
        shutil.copytree(ROOT / 'pocketbase/pb_hooks', cls.work / 'hooks')
        # Production already applied the first migration; stage the follow-up on top of seeded data.
        shutil.copytree(ROOT / 'pocketbase/pb_migrations', cls.work / 'migrations', ignore=shutil.ignore_patterns(FOLLOWUP))
        # This route exists ONLY in a disposable local fixture, never in deployment hooks.
        (cls.work / 'hooks/test_only.pb.js').write_text('''
routerAdd('POST', '/api/test-only', (e) => {
  if (!e.hasSuperuserAuth()) return e.json(403, {});
  const body = e.requestInfo().body;
  const sm = require(`${__hooks}/stone_match.js`);
  if (body.operation === 'otherAuth') return e.json(200, {token: e.app.findRecordsByFilter('users', '', '', 1, 0)[0].newAuthToken()});
  if (body.operation === 'purge') { sm.purge(e.app, body.kind, body.ms); return e.json(200, {}); }
  return e.json(200, {week: sm.week(body.ms), date: sm.dateKst(body.ms), stamp: sm.stamp(body.stamp)});
});
''')
        (cls.work / 'migrations/1700000000_existing_fixture.js').write_text("""
migrate((app) => {
  const users = app.findCollectionByNameOrId('users');
  const user = new Record(users); user.set('email', 'existing@example.invalid');
  user.setPassword($security.randomString(40)); app.save(user);
  const tasks = new Collection({name: 'tasks', type: 'base', fields: [{name: 'title', type: 'text'},
    {name: 'owner', type: 'relation', collectionId: users.id, maxSelect: 1}]}); app.save(tasks);
  const task = new Record(tasks); task.set('title', 'must remain untouched'); task.set('owner', user.id); app.save(task);
}, () => {});
""")
        cls.args = [str(BIN), '--dir=' + str(cls.work / 'data'),
                    '--hooksDir=' + str(cls.work / 'hooks'), '--migrationsDir=' + str(cls.work / 'migrations')]
        cls.email = 'local-test@example.invalid'
        cls.password = secrets.token_hex(32)
        subprocess.run(cls.args + ['migrate', 'up'], check=True, capture_output=True)
        cls.seed_before_followup()
        shutil.copy(ROOT / 'pocketbase/pb_migrations' / FOLLOWUP, cls.work / 'migrations' / FOLLOWUP)
        subprocess.run(cls.args + ['migrate', 'up'], check=True, capture_output=True)
        subprocess.run(cls.args + ['superuser', 'upsert', cls.email, cls.password], check=True, capture_output=True)
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            cls.port = sock.getsockname()[1]
        cls.base = 'http://127.0.0.1:' + str(cls.port)
        cls.log = (cls.work / 'runtime.log').open('a')
        cls.start()
        code, data = cls.request('/api/collections/_superusers/auth-with-password', {'identity': cls.email, 'password': cls.password})
        assert code == 200, data
        cls.admin = data['token']
        cls.existing_users = cls.request('/api/collections/users/records', token=cls.admin, method='GET')[1]['items']
        cls.existing_tasks = cls.request('/api/collections/tasks/records', token=cls.admin, method='GET')[1]['items']

    @classmethod
    def seed_before_followup(cls):
        # Synthetic stand-in for the 353 imported legacy rows (player empty) plus post-import duplicates.
        cls.legacy_day = kst_day(-20)
        cls.legacy_users = [str(uuid.uuid4()) for _ in range(5)]
        shared = [str(uuid.uuid4()) for _ in range(3)]
        rows = []
        for n in range(353):
            params = {} if n % 4 == 0 else {'schema_version': 1, 'event_id': str(uuid.uuid4())}
            if n < 6:
                params = {'schema_version': 1, 'event_id': shared[n % 3]}  # same owner below: legacy duplicate
            if n == 7:
                params = {'event_id': 'not-a-uuid'}
            if n == 8:
                params = {'event_id': str(uuid.uuid4()).upper()}
            user = cls.legacy_users[0] if n < 6 else cls.legacy_users[n % 5]
            rows.append(('', str(uuid.uuid4()), user, str(uuid.uuid4()), 'round_end', json.dumps(params), at(cls.legacy_day, 1 + n % 20)))
        cls.dupe_id = str(uuid.uuid4())
        for player, name, hour in [('seedplayer00001', 'later', 3), ('seedplayer00001', 'earliest', 2), ('seedplayer00002', 'other_owner', 4)]:
            rows.append((player, '', '', str(uuid.uuid4()), name, json.dumps({'schema_version': 3, 'event_id': cls.dupe_id}), at(kst_day(-1), hour)))
        with sqlite3.connect(cls.work / 'data/data.db') as db:
            db.executemany('INSERT INTO sm_events (player, legacy_id, legacy_user_id, session_id, name, params, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)', rows)
        cls.legacy_before = cls.legacy_snapshot()

    @classmethod
    def legacy_snapshot(cls):
        users = ','.join('?' * len(cls.legacy_users))
        with sqlite3.connect(cls.work / 'data/data.db') as db:
            return db.execute('SELECT id, player, legacy_id, legacy_user_id, session_id, name, params, created_at FROM sm_events '
                              "WHERE legacy_id != '' AND legacy_user_id IN (" + users + ') ORDER BY id', cls.legacy_users).fetchall()

    @classmethod
    def start(cls):
        cls.proc = subprocess.Popen(cls.args + ['serve', '--hooksWatch=false', '--http=127.0.0.1:' + str(cls.port)], stdout=cls.log, stderr=cls.log)
        for _ in range(100):
            try:
                if cls.request('/api/stone-match/health', method='GET')[0] == 200:
                    return
            except OSError:
                pass
            if cls.proc.poll() is not None:
                break
            time.sleep(.05)
        raise RuntimeError('Local runtime did not start: ' + str(cls.work))

    @classmethod
    def tearDownClass(cls):
        cls.proc.terminate()
        cls.proc.wait(timeout=10)
        cls.log.close()
        # Keep local evidence/database in task scratch, never in version control.

    @classmethod
    def request(cls, path, body=None, token='', method='POST'):
        data = None if body is None else json.dumps(body, ensure_ascii=False).encode()
        headers = {'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = token
        request = urllib.request.Request(cls.base + path, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                raw = response.read()
                return response.status, json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            raw = error.read()
            return error.code, json.loads(raw) if raw else None

    def api(self, path, body=None, token='', method='POST'):
        return self.request('/api/stone-match/' + path, body, token, method)

    def guest(self):
        credential = {'device_id': secrets.token_hex(16), 'device_secret': secrets.token_hex(32)}
        code, result = self.api('auth/guest', credential)
        self.assertEqual(code, 200, result)
        return credential, result['token'], result['record']['id']

    def insert(self, collection, data):
        code, result = self.request('/api/collections/' + collection + '/records', data, self.admin)
        self.assertEqual(code, 200, result)
        return result

    def records(self, collection, filter_value=''):
        from urllib.parse import urlencode
        path = '/api/collections/' + collection + '/records?' + urlencode({'perPage': 500, 'filter': filter_value})
        code, result = self.request(path, token=self.admin, method='GET')
        self.assertEqual(code, 200, result)
        return result['items']

    def update(self, collection, id_value, data):
        code, result = self.request('/api/collections/' + collection + '/records/' + id_value, data, self.admin, 'PATCH')
        self.assertEqual(code, 200, result)
        return result

    def row(self, **extra):
        return dict(session_id=str(uuid.uuid4()), name='round_end', params={'schema_version': 3, 'event_id': str(uuid.uuid4()), 'event_seq': 1},
                    app_version='1.0.0', channel='web', client_ts=iso(), **extra)

    def test_01_schema_defaults_and_migration_restart(self):
        code, data = self.api('config/gameplay', method='GET')
        self.assertEqual(code, 200)
        self.assertEqual(data, [{'value': {'time_reward_t1': False, 'time_gem': False, 'multiplier_gem': False,
                                         'seventh_color_from_level': None, 'last_hurrah_combo_multiplier': False}}])
        code, collections = self.request('/api/collections', token=self.admin, method='GET')
        self.assertEqual(code, 200)
        names = {c['name'] for c in collections['items']}
        self.assertNotIn('sm_legacy_players', names)
        for c in collections['items']:
            if c['name'].startswith('sm_'):
                for rule in ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule']:
                    self.assertIsNone(c[rule])
        credentials, token, player = self.guest()
        self.proc.terminate(); self.proc.wait(timeout=10)
        subprocess.run(self.args + ['migrate', 'up'], check=True, capture_output=True)
        self.start()
        self.assertEqual(self.api('auth/guest', credentials)[1]['record']['id'], player)
        self.assertEqual(self.api('ads/status', {}, token)[0], 200)

    def test_02_guest_mismatch_restore_and_concurrency(self):
        credentials, token, player = self.guest()
        result = self.api('auth/guest', dict(credentials, device_secret=secrets.token_hex(32)))
        self.assertEqual(result, (401, {'code': 'unauthorized'}))
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(lambda _: self.api('auth/guest', credentials), range(8)))
        self.assertTrue(all(c == 200 and r['record']['id'] == player for c, r in results), results)
        fresh = {'device_id': secrets.token_hex(16), 'device_secret': secrets.token_hex(32)}
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            created = list(pool.map(lambda _: self.api('auth/guest', fresh), range(8)))
        self.assertTrue(all(c == 200 for c, r in created), created)
        self.assertEqual(len({r['record']['id'] for c, r in created}), 1)
        payload = json.loads(base64.urlsafe_b64decode(token.split('.')[1] + '=='))
        self.assertAlmostEqual(payload['exp'] - time.time(), 604800, delta=5)
        self.assertEqual(set(results[0][1]), {'token', 'record', 'expires_in'})
        self.assertEqual(set(results[0][1]['record']), {'id'})
        # Invalidate an old session using PocketBase's real password/token-key semantics.
        self.update('sm_players', player, {'password': credentials['device_secret'], 'passwordConfirm': credentials['device_secret']})
        self.assertEqual(self.api('ads/status', {}, token)[0], 401)
        restored = self.api('auth/guest', credentials)
        self.assertEqual(restored[0], 200, restored)
        self.assertEqual(restored[1]['record']['id'], player)
        self.assertEqual(self.api('ads/status', {}, restored[1]['token'])[0], 200)
        for invalid in [{}, dict(credentials, device_id='x'), dict(credentials, device_secret='x')]:
            self.assertEqual(self.api('auth/guest', invalid)[0], 400)

    def test_03_public_privileges(self):
        credentials, token, player = self.guest()
        for auth in ['', token]:
            for collection in ['sm_players', 'sm_rankings', 'sm_ad_claims', 'sm_events', 'sm_config']:
                path = '/api/collections/' + collection + '/records'
                self.assertIn(self.request(path, token=auth, method='GET')[0], [401, 403])
                self.assertIn(self.request(path, {}, auth)[0], [401, 403])
                id_value = player if collection == 'sm_players' else self.records(collection)[0]['id'] if self.records(collection) else 'aaaaaaaaaaaaaaa'
                for method in ['GET', 'PATCH', 'DELETE']:
                    self.assertIn(self.request(path + '/' + id_value, {} if method == 'PATCH' else None, auth, method)[0], [401, 403, 404])
            self.assertNotEqual(self.request('/api/collections/sm_players/auth-with-password', {'identity': credentials['device_id'], 'password': credentials['device_secret']}, auth)[0], 200)
            self.assertNotEqual(self.request('/api/collections/sm_players/auth-refresh', {}, auth)[0], 200)
        other_token = self.request('/api/test-only', {'operation': 'otherAuth'}, self.admin)[1]['token']
        for path in ['ranking/submit', 'ads/status', 'ads/claim', 'events']:
            self.assertEqual(self.api(path, {}, '')[0], 401)
            self.assertEqual(self.api(path, {}, self.admin)[0], 401)
            self.assertEqual(self.api(path, {}, other_token)[0], 401)
        self.assertEqual(self.api('unknown', {})[0], 404)
        self.assertEqual(self.request('/api/test-only', {}, token)[0], 403)

    def test_04_rank_validation_and_unicode(self):
        _, token, _ = self.guest()
        for mode, score in [('bad', 1), ('time', 0), ('time', 1000000001), ('level', 10001), ('time', 1.5), ('time', True)]:
            self.assertEqual(self.api('ranking/submit', {'p_mode': mode, 'p_name': 'Test', 'p_score': score}, token)[0], 400)
        for value in ['', '   ', None, '\0']:
            self.assertEqual(self.api('ranking/submit', {'p_mode': 'level', 'p_name': value, 'p_score': 1}, token)[0], 400)
        names = [('  A\u200b\u202eB  ', 'AB'), ('\u200b\u3164', 'GUEST'), ('\u200d\ufe0f', 'GUEST'), ('😀' * 21, '😀' * 20), ('가족👨\u200d👩', '가족👨\u200d👩')]
        for raw, expected in names:
            code, data = self.api('ranking/submit', {'p_mode': 'level', 'p_name': raw, 'p_score': 7}, token)
            self.assertEqual(code, 200, data)
            self.assertNotIn('week_start', data)
            rows = self.records('sm_rankings', 'player = "' + self.guest_id(token) + '"')
            self.assertIn(expected, [r['name'] for r in rows])
        self.assertEqual(self.api('ranking/list', {'p_mode': 'x'})[0], 400)
        self.assertEqual(self.api('ranking/list', {'p_mode': 'level', 'p_limit': 1.5})[0], 400)

    def guest_id(self, token):
        return json.loads(base64.urlsafe_b64decode(token.split('.')[1] + '=='))['id']

    def test_05_rank_import_order_week_and_privacy(self):
        current = dt.datetime.now(UTC)
        old = current - dt.timedelta(days=8)
        _, token, player = self.guest()
        seq = max([r['order_seq'] for r in self.records('sm_rankings')] + [0]) + 10
        for name_value, stamp_value, sequence in [('earlier', iso(old), seq), ('micro_early', iso(current).split('.')[0] + '.123456Z', seq + 2), ('micro_late', iso(current).split('.')[0] + '.123457Z', seq + 1), ('tie_late', iso(current).split('.')[0] + '.123457Z', seq + 3)]:
            self.insert('sm_rankings', dict(legacy_id=str(uuid.uuid4()), legacy_user_id='private-original-uuid', mode='time', name=name_value, score=999999999, created_at=stamp_value, order_seq=sequence, week_start='2000-01-01'))
        code, data = self.api('ranking/list', {'p_mode': 'time', 'p_limit': 100})
        self.assertEqual(code, 200, data)
        self.assertEqual([r['name'] for r in data[:3]], ['micro_early', 'micro_late', 'tie_late'])
        self.assertNotIn('earlier', [r['name'] for r in data])
        self.assertTrue(all(set(r) == {'name', 'score', 'ts'} for r in data))
        submitted = self.api('ranking/submit', {'p_mode': 'time', 'p_name': 'new', 'p_score': 999999999}, token)
        self.assertEqual(submitted[0], 200, submitted)
        rows = self.records('sm_rankings', 'player = "' + player + '"')
        self.assertEqual(rows[0]['order_seq'], seq + 4)
        # Admin API duplicate legacy IDs are rejected, missing player is importable.
        duplicate = dict(rows[0]); duplicate.pop('id'); duplicate['order_seq'] += 1
        duplicate['legacy_id'] = 'duplicate-' + str(uuid.uuid4())
        self.insert('sm_rankings', duplicate)
        duplicate['order_seq'] += 1
        self.assertEqual(self.request('/api/collections/sm_rankings/records', duplicate, self.admin)[0], 400)
        code, result = self.request('/api/test-only', {'ms': int(dt.datetime(2026, 9, 27, 15, tzinfo=UTC).timestamp() * 1000), 'stamp': '2026-09-29T21:00:00.123456+09:00'}, self.admin)
        self.assertEqual(result, {'week': '2026-09-28', 'date': '2026-09-28', 'stamp': '2026-09-29T12:00:00.123456Z'})
        result = self.request('/api/test-only', {'ms': int(dt.datetime(2026, 9, 27, 14, 59, 59, tzinfo=UTC).timestamp() * 1000), 'stamp': '2026-09-29T12:00:00Z'}, self.admin)[1]
        self.assertEqual(result['week'], '2026-09-21')

    def test_06_concurrent_ranking_quota(self):
        _, token, player = self.guest()
        with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
            results = list(pool.map(lambda _: self.api('ranking/submit', {'p_mode': 'level', 'p_name': 'quota', 'p_score': 50}, token), range(20)))
        self.assertEqual(sum(code == 200 for code, _ in results), 10, results)
        self.assertEqual(sum(code == 429 for code, _ in results), 10, results)
        self.assertEqual(len(self.records('sm_rankings', 'player = "' + player + '"')), 10)
        ranks = [r['rank'] for c, r in results if c == 200]
        self.assertEqual(len(set(ranks)), 10)

    def test_07_concurrent_ads_config_and_dates(self):
        _, token, player = self.guest()
        with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
            results = list(pool.map(lambda _: self.api('ads/claim', {'p_item': 'addTime'}, token), range(24)))
        self.assertTrue(all(code == 200 for code, _ in results), results)
        self.assertEqual(sum(r['granted'] for _, r in results), 3)
        self.assertEqual(len(self.records('sm_ad_claims', 'player = "' + player + '"')), 3)
        self.assertEqual(self.api('ads/status', {}, token)[1]['remaining'], 0)
        self.assertEqual(self.api('ads/claim', {'p_item': '!invalid'}, token)[0], 400)
        ads = self.records('sm_config', 'key = "ads"')[0]
        try:
            for configured, expected in [(-2, 0), (0, 0), (30, 20)]:
                self.update('sm_config', ads['id'], {'value': {'daily_refill_limit': configured}})
                self.assertEqual(self.api('ads/status', {}, token)[1]['daily_limit'], expected)
        finally:
            self.update('sm_config', ads['id'], {'value': {'daily_refill_limit': 3}})

    def test_08_events_atomic_validation_and_utf8(self):
        _, token, player = self.guest()
        row = self.row()
        self.assertEqual(self.api('events', [row], token)[0], 204)
        self.assertEqual(self.records('sm_events', 'player = "' + player + '"')[0]['params'], row['params'])
        variants = [dict(row, session_id='bad'), dict(row, name='Bad'), dict(row, params=[]), dict(row, params={'x': '가' * 700}), dict(row, app_version='a' * 33), dict(row, channel='a' * 17), dict(row, client_ts='bad'), dict(row, client_ts='2026-02-30T00:00:00Z'), dict(row, player=player)]
        for bad in variants:
            self.assertEqual(self.api('events', [row, bad], token)[0], 400, bad)
        for bad in [[], [row] * 201, {}]:
            self.assertEqual(self.api('events', bad, token)[0], 400)
        self.assertEqual(len(self.records('sm_events', 'player = "' + player + '"')), 1)
        # Identical resend is accepted and stored once.
        self.assertEqual(self.api('events', [row], token)[0], 204)
        self.assertEqual(len(self.records('sm_events', 'player = "' + player + '"')), 1)

    def test_08b_event_exact_byte_limits(self):
        _, token, player = self.guest()
        row = self.row()
        for value in ['a' * 2040, '<' * 400, '가' * 680]:
            self.assertEqual(self.api('events', [dict(row, params={'x': value})], token)[0], 204)
        self.assertEqual(self.api('events', [dict(row, params={'x': 'a' * 2041})], token)[0], 400)
        imported = self.insert('sm_events', dict(row, params={'x': '<' * 400}, created_at=iso(), legacy_id=str(uuid.uuid4())))
        self.assertEqual(imported['params'], {'x': '<' * 400})
        self.assertEqual(self.api('events', [dict(row, params={'x': '\\u0000'})], token)[0], 204)
        self.assertEqual(self.api('events', [dict(row, params={'x': '\0'})], token)[0], 400)

    def test_09_concurrent_event_quota(self):
        _, token, player = self.guest()
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(lambda _: self.api('events', [self.row() for _ in range(100)], token), range(8)))
        self.assertEqual(sum(code == 204 for code, _ in results), 3, results)
        self.assertEqual(sum(code == 429 for code, _ in results), 5, results)
        self.assertEqual(len(self.records('sm_events', 'player = "' + player + '"')), 300)

    def test_10_retention_and_activity(self):
        now = dt.datetime.now(UTC)
        ms = int(now.timestamp() * 1000)
        cutoff = iso(dt.datetime.fromtimestamp(ms / 1000, UTC) - dt.timedelta(days=90))
        old = iso(now - dt.timedelta(days=91))
        stale_credentials, token, stale = self.guest()
        _, active_token, active = self.guest()
        for player in [stale, active]:
            self.update('sm_players', player, {'created_at': old, 'last_active_at': old})
        self.assertEqual(self.api('ads/status', {}, active_token)[0], 200)
        self.assertGreater(self.records('sm_players', 'id = "' + active + '"')[0]['last_active_at'], cutoff)
        seq = max(r['order_seq'] for r in self.records('sm_rankings')) + 1
        ranking = self.insert('sm_rankings', dict(player=stale, mode='level', name='preserved', score=100, created_at=old, order_seq=seq, week_start='2000-01-01'))
        for player, created in [(stale, iso()), (active, old), (active, cutoff), (active, iso())]:
            self.insert('sm_events', dict(self.row(), player=player, created_at=created))
        kst_today = (now + dt.timedelta(hours=9)).date()
        boundary = str(kst_today - dt.timedelta(days=35))
        for player, day in [(stale, str(kst_today)), (active, str(kst_today - dt.timedelta(days=36))), (active, boundary)]:
            self.insert('sm_ad_claims', dict(player=player, item='hint', claim_date=day, created_at=iso()))
        legacy = self.insert('sm_events', dict(self.row(), params={}, legacy_id=str(uuid.uuid4()), legacy_user_id=str(uuid.uuid4()), created_at=iso()))
        for kind in ['events', 'ads', 'players']:
            self.assertEqual(self.request('/api/test-only', {'operation': 'purge', 'kind': kind, 'ms': ms}, self.admin)[0], 200)
        self.assertEqual(self.records('sm_players', 'id = "' + stale + '"'), [])
        self.assertEqual(self.api('ads/status', {}, token)[0], 401)
        kept = self.records('sm_rankings', 'id = "' + ranking['id'] + '"')[0]
        self.assertEqual(kept['player'], '')
        self.assertEqual(kept['name'], 'preserved')
        self.assertEqual(len(self.records('sm_events', 'player = "' + active + '"')), 2)
        self.assertEqual(len(self.records('sm_ad_claims', 'player = "' + active + '"')), 1)
        self.assertEqual(self.records('sm_events', 'player = "' + stale + '"'), [])

        self.assertEqual(self.records('sm_events', 'id = "' + legacy['id'] + '"')[0]['params'], {})
        restored = self.api('auth/guest', stale_credentials)
        self.assertEqual(restored[0], 200, restored)
        self.assertNotEqual(restored[1]['record']['id'], stale)
        self.assertEqual(self.records('users'), self.existing_users)
        self.assertEqual(self.records('tasks'), self.existing_tasks)

    def test_11_admin_delete_relation_behavior(self):
        _, token, player = self.guest()
        self.assertEqual(self.api('ranking/submit', {'p_mode': 'level', 'p_name': 'keep', 'p_score': 1}, token)[0], 200)
        self.assertEqual(self.api('events', [self.row()], token)[0], 204)
        self.assertEqual(self.api('ads/claim', {'p_item': 'hint'}, token)[0], 200)
        ranking = self.records('sm_rankings', 'player = "' + player + '"')[0]
        event = self.records('sm_events', 'player = "' + player + '"')[0]
        ad = self.records('sm_ad_claims', 'player = "' + player + '"')[0]
        self.assertEqual(self.request('/api/collections/sm_players/records/' + player, token=self.admin, method='DELETE')[0], 204)
        self.assertEqual(self.records('sm_rankings', 'id = "' + ranking['id'] + '"')[0]['player'], '')
        self.assertEqual(self.records('sm_events', 'id = "' + event['id'] + '"'), [])
        self.assertEqual(self.records('sm_ad_claims', 'id = "' + ad['id'] + '"'), [])


    def test_12_real_expiry_restore(self):
        code, collection = self.request('/api/collections/sm_players', token=self.admin, method='GET')
        self.assertEqual(code, 200)
        code, result = self.request('/api/collections/sm_players', {'authToken': {'duration': 10}}, self.admin, 'PATCH')
        self.assertEqual(code, 200, result)
        try:
            credentials, token, player = self.guest()
            time.sleep(10.1)
            self.assertEqual(self.api('ads/status', {}, token)[0], 401)
        finally:
            self.assertEqual(self.request('/api/collections/sm_players', {'authToken': {'duration': 604800}}, self.admin, 'PATCH')[0], 200)
        code, restored = self.api('auth/guest', credentials)
        self.assertEqual(code, 200, restored)
        self.assertEqual(restored['record']['id'], player)
        self.assertEqual(self.api('ads/status', {}, restored['token'])[0], 200)

    def test_13_activity_all_accepted_calls(self):
        credentials, token, player = self.guest()
        old = iso(dt.datetime.now(UTC) - dt.timedelta(days=91))
        for route, body, method in [('ranking/submit', {'p_mode': 'level', 'p_name': 'activity', 'p_score': 2}, 'POST'),
                                     ('ads/claim', {'p_item': 'hint'}, 'POST'), ('events', [self.row()], 'POST'),
                                     ('ranking/list', {'p_mode': 'level'}, 'POST'), ('config/gameplay', None, 'GET'),
                                     ('health', None, 'GET')]:
            self.update('sm_players', player, {'last_active_at': old})
            code, data = self.api(route, body, token, method)
            self.assertIn(code, [200, 204], data)
            self.assertGreater(self.records('sm_players', 'id = "' + player + '"')[0]['last_active_at'], old)
        self.update('sm_players', player, {'last_active_at': old})
        self.assertEqual(self.api('events', [{}], token)[0], 400)
        self.assertEqual(self.records('sm_players', 'id = "' + player + '"')[0]['last_active_at'], old)

    def test_14_quota_window_and_config_ranking(self):
        _, token, player = self.guest()
        old = iso(dt.datetime.now(UTC) - dt.timedelta(seconds=61))
        seq = max(r['order_seq'] for r in self.records('sm_rankings')) + 1
        for n in range(10):
            self.insert('sm_rankings', dict(player=player, mode='level', name='oldquota', score=1, created_at=old, order_seq=seq+n, week_start='2000-01-01'))
        self.assertEqual(self.api('ranking/submit', {'p_mode': 'level', 'p_name': 'afterminute', 'p_score': 2}, token)[0], 200)
        config = self.records('sm_config', 'key = "ranking"')[0]
        try:
            self.update('sm_config', config['id'], {'value': {'list_limit': 1}})
            self.assertEqual(len(self.api('ranking/list', {'p_mode': 'level'})[1]), 1)
            code, result = self.api('ranking/submit', {'p_mode': 'level', 'p_name': 'notranked', 'p_score': 1}, token)
            self.assertEqual(code, 200)
            self.assertFalse(result['ranked'])
            self.assertEqual(len(self.api('ranking/list', {'p_mode': 'level', 'p_limit': -3})[1]), 1)
        finally:
            self.update('sm_config', config['id'], {'value': {'list_limit': 30}})
        self.assertEqual(self.records('users'), self.existing_users)
        self.assertEqual(self.records('tasks'), self.existing_tasks)


    def test_15_public_epoch_rounding(self):
        seq = max(r['order_seq'] for r in self.records('sm_rankings')) + 1
        second = int(dt.datetime(2026, 9, 29, tzinfo=UTC).timestamp())
        for n, fraction in enumerate(['499999', '500000']):
            self.insert('sm_rankings', dict(mode='level', name='epoch_' + fraction, score=9999,
                created_at='2026-09-29T00:00:00.' + fraction + 'Z', order_seq=seq+n, week_start='2000-01-01'))
        code, rows = self.api('ranking/list', {'p_mode': 'level', 'p_limit': 100})
        self.assertEqual(code, 200)
        found = {r['name']: r['ts'] for r in rows}
        self.assertEqual(found['epoch_499999'], second)
        self.assertEqual(found['epoch_500000'], second + 1)


    # --- PLAN-009 Step 4: event_id dedupe and daily metrics (migration 1790800000) ---

    def rebuild(self, first, last=None, token=None):
        return self.request('/api/stone-match/admin/metrics/rebuild', {'from': str(first), 'to': str(last or first)}, self.admin if token is None else token)

    def metrics(self, day):
        rows = self.records('sm_daily_metrics', 'day = "' + str(day) + '"')
        return {r['key']: r for r in rows}

    @staticmethod
    def stable(rows):
        return {k: {f: v for f, v in r.items() if f not in ('id', 'computed_at', 'created', 'updated')} for k, r in rows.items()}

    def test_16_followup_migration_preserves_legacy_and_dedupes(self):
        self.assertEqual(self.legacy_snapshot(), self.legacy_before)
        self.assertEqual(len(self.legacy_before), 353)
        with sqlite3.connect(self.work / 'data/data.db') as db:
            ids = dict(db.execute("SELECT json_extract(params, '$.event_id'), event_id FROM sm_events WHERE legacy_id != '' AND json_extract(params, '$.event_id') IS NOT NULL").fetchall())
            index = db.execute("SELECT sql FROM sqlite_master WHERE name = 'sm_events_dedupe'").fetchone()[0]
        self.assertEqual(ids['not-a-uuid'], '')
        self.assertTrue(all(v == k.lower() for k, v in ids.items() if k != 'not-a-uuid'))
        self.assertIn("legacy_id = ''", index)
        kept = self.records('sm_events', 'event_id = "' + self.dupe_id + '"')
        self.assertEqual(sorted(r['name'] for r in kept), ['earliest', 'other_owner'])
        code, collection = self.request('/api/collections/sm_daily_metrics', token=self.admin, method='GET')
        self.assertEqual(code, 200)
        for rule in ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule']:
            self.assertIsNone(collection[rule])
        # Legacy rows: empty player, counted per legacy_user_id, legacy duplicates counted once.
        self.assertEqual(self.rebuild(self.legacy_day)[0], 200)
        day = self.metrics(self.legacy_day)['day|%s|*|*|*|*|*' % self.legacy_day]
        self.assertEqual((day['raw_rows'], day['events'], day['players'], day['sessions']), (353, 350, 5, 353))
        self.assertIn('env|%s|unknown|*|*|*|*' % self.legacy_day, self.metrics(self.legacy_day))
        self.assertEqual(self.legacy_snapshot(), self.legacy_before)

    def test_17_concurrent_resend_consumes_quota_once(self):
        _, token, player = self.guest()
        batch = [self.row() for _ in range(200)]
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(lambda _: self.api('events', batch, token), range(8)))
        self.assertEqual([c for c, _ in results], [204] * 8, results)
        self.assertEqual(len(self.records('sm_events', 'player = "' + player + '"')), 200)
        self.assertEqual(self.api('events', [self.row() for _ in range(100)], token)[0], 204)
        self.assertEqual(self.api('events', batch, token)[0], 204)  # duplicates only: no quota use
        self.assertEqual(self.api('events', batch[:10] + [self.row()], token)[0], 429)
        self.assertEqual(len(self.records('sm_events', 'player = "' + player + '"')), 300)

    def test_18_duplicate_content_conflict_is_atomic(self):
        _, token, player = self.guest()
        _, other_token, other = self.guest()
        row = self.row()
        self.assertEqual(self.api('events', [row], token)[0], 204)
        fresh = self.row()
        changed = [dict(row, params=dict(row['params'], score=1)), dict(row, name='round_start'), dict(row, session_id=str(uuid.uuid4())),
                   dict(row, channel='ios'), dict(row, app_version='2.0.0'), dict(row, client_ts=iso(dt.datetime.now(UTC) + dt.timedelta(seconds=1)))]
        for bad in changed:
            self.assertEqual(self.api('events', [fresh, bad], token), (400, {'code': 'rejected'}), bad)
        twin = self.row()
        self.assertEqual(self.api('events', [twin, dict(twin, params=dict(twin['params'], x=1))], token)[0], 400)
        self.assertEqual(len(self.records('sm_events', 'player = "' + player + '"')), 1)
        # Same meaning, different spelling: key order, session case, equivalent timestamp.
        same = dict(row, params=dict(reversed(list(row['params'].items()))), session_id=row['session_id'].upper(),
                    client_ts=row['client_ts'].replace('Z', '+00:00'))
        self.assertEqual(self.api('events', [same, fresh, fresh], token)[0], 204)
        self.assertEqual(len(self.records('sm_events', 'player = "' + player + '"')), 2)
        # Scope is per player.
        self.assertEqual(self.api('events', [row], other_token)[0], 204)
        self.assertEqual(len(self.records('sm_events', 'player = "' + other + '"')), 1)
        # Admin API cannot create a second live row with the same owner/id either.
        stored = self.records('sm_events', 'player = "' + player + '"')[0]
        duplicate = {k: stored[k] for k in ['player', 'session_id', 'name', 'params', 'app_version', 'channel', 'client_ts', 'created_at']}
        self.assertEqual(self.request('/api/collections/sm_events/records', duplicate, self.admin)[0], 400)

    def test_19_old_clients_without_event_id_are_accepted(self):
        _, token, player = self.guest()
        old = dict(self.row(), params={'schema_version': 0})
        invalid = dict(self.row(), params={'event_id': 'abc'})
        for batch in [[old, old], [old], [invalid, invalid]]:
            self.assertEqual(self.api('events', batch, token)[0], 204)
        rows = self.records('sm_events', 'player = "' + player + '"')
        self.assertEqual(len(rows), 5)
        self.assertTrue(all(r['event_id'] == '' for r in rows))

    def test_20_daily_metrics_rounds_env_boundaries_and_rerun(self):
        day, next_day = kst_day(-10), kst_day(-9)
        _, _, p1 = self.guest()
        _, _, p2 = self.guest()
        s1, s2, run = str(uuid.uuid4()), str(uuid.uuid4()), str(uuid.uuid4())

        def add(player, session, name, created, env='production', event_id=None, mode='progression', **params):
            params = dict(params, schema_version=3, telemetry_env=env, mode=mode)
            if event_id is not False:
                params['event_id'] = event_id or str(uuid.uuid4())
            return self.insert('sm_events', dict(player=player, session_id=session, name=name, params=params, app_version='1.0.0',
                                                 channel='web', client_ts=created, created_at=created))
        add(p1, s1, 'round_start', at(day, 10), run_id=run, round_seq=1, attempt_seq=0)
        add(p1, s1, 'round_end', at(day, 10, 5), run_id=run, round_seq=1, attempt_seq=0, reason='time_up')
        add(p1, s1, 'round_start', at(day, 23, 59, 59, 999999), run_id=run, round_seq=2, attempt_seq=0)  # never ends
        add(p2, s2, 'round_start', at(next_day, 0), env='qa', run_id=str(uuid.uuid4()), round_seq=1, attempt_seq=0)
        for _ in range(2):
            add(p2, s2, 'menu_open', at(day, 12), event_id=False)  # old client: no id, both counted
        self.assertEqual(self.rebuild(day, next_day)[0], 200)
        first = self.metrics(day)
        d = first['day|%s|*|*|*|*|*' % day]
        self.assertEqual((d['raw_rows'], d['events'], d['players'], d['sessions']), (5, 5, 2, 2))
        rounds = first['rounds|%s|production|web|1.0.0|progression|round_start' % day]
        self.assertEqual((rounds['round_starts'], rounds['rounds_ended'], rounds['rounds_unknown'], rounds['attempt_ends']), (2, 1, 1, 1))
        self.assertNotIn('crash', json.dumps(rounds))
        self.assertEqual(first['event|%s|production|web|1.0.0|progression|menu_open' % day]['events'], 2)
        self.assertFalse([k for k in first if '|qa|' in k])
        qa = self.metrics(next_day)['rounds|%s|qa|web|1.0.0|progression|round_start' % next_day]
        self.assertEqual((qa['round_starts'], qa['rounds_unknown']), (1, 1))
        self.assertEqual(self.metrics(next_day)['env|%s|qa|*|*|*|*' % next_day]['players'], 1)
        # Rerun is idempotent; a late attempt end arriving the next day resolves the earlier cohort.
        self.assertEqual(self.rebuild(day)[0], 200)
        self.assertEqual(self.stable(self.metrics(day)), self.stable(first))
        add(p1, s1, 'stage_continue', at(day, 10, 6), run_id=run, round_seq=1, attempt_seq=1)
        add(p1, s1, 'round_end', at(next_day, 0, 30), run_id=run, round_seq=1, attempt_seq=1, reason='level_clear')
        self.assertEqual(self.rebuild(day)[0], 200)
        rounds = self.metrics(day)['rounds|%s|production|web|1.0.0|progression|round_start' % day]
        self.assertEqual((rounds['round_starts'], rounds['rounds_ended'], rounds['rounds_unknown'], rounds['attempt_ends']), (2, 1, 1, 2))
        # An end received 8+ KST days after the start day is outside the matching window: still unknown.
        late_run = str(uuid.uuid4())
        add(p1, s1, 'round_start', at(day, 11), run_id=late_run, round_seq=1, attempt_seq=0)
        add(p1, s1, 'round_end', at(day + dt.timedelta(days=8), 0), run_id=late_run, round_seq=1, attempt_seq=0, reason='exit')
        self.assertEqual(self.rebuild(day)[0], 200)
        rounds = self.metrics(day)['rounds|%s|production|web|1.0.0|progression|round_start' % day]
        self.assertEqual((rounds['round_starts'], rounds['rounds_ended'], rounds['rounds_unknown'], rounds['attempt_ends']), (3, 1, 2, 2))
        # QA toggled mid-round (end arrives late, tagged qa): not a production end, not unknown either.
        qa_run = str(uuid.uuid4())
        add(p1, s1, 'round_start', at(day, 14), run_id=qa_run, round_seq=1, attempt_seq=0)
        add(p1, s1, 'round_end', at(next_day, 1), env='qa', run_id=qa_run, round_seq=1, attempt_seq=0, reason='exit')
        self.assertEqual(self.rebuild(day)[0], 200)
        rounds = self.metrics(day)['rounds|%s|production|web|1.0.0|progression|round_start' % day]
        self.assertEqual((rounds['round_starts'], rounds['rounds_ended'], rounds['rounds_env_changed'], rounds['rounds_unknown'], rounds['attempt_ends'],
                          rounds['completeness']), (4, 1, 1, 2, 2, 'complete'))
        self.assertFalse([k for k in self.metrics(day) if k.startswith('rounds|%s|qa|' % day)])
        self.assertEqual(self.rebuild(next_day)[0], 200)
        self.assertEqual(self.metrics(next_day)['rounds|%s|qa|web|1.0.0|progression|round_start' % next_day]['rounds_env_changed'], 0)
        # Real client JewelGameMode values keep their own mode dimension.
        for mode in ['simple', 'timed']:
            add(p2, s2, 'round_start', at(day, 15), mode=mode, run_id=str(uuid.uuid4()), round_seq=1, attempt_seq=0)
        self.assertEqual(self.rebuild(day)[0], 200)
        for mode in ['simple', 'timed']:
            self.assertEqual(self.metrics(day)['rounds|%s|production|web|1.0.0|%s|round_start' % (day, mode)]['round_starts'], 1)
        # Client strings cannot break the nightly job: '|' label collisions and unknown env/mode values.
        for channel, version in [('a|b', '1'), ('a', 'b|1')]:
            self.insert('sm_events', dict(player=p2, session_id=s2, name='odd', params={'telemetry_env': 'prod|x', 'mode': 1},
                                          app_version=version, channel=channel, created_at=at(day, 13)))
        self.assertEqual(self.rebuild(day)[0], 200)
        odd = [r for r in self.records('sm_daily_metrics', 'day = "%s" && event_name = "odd"' % day)]
        self.assertEqual(sorted((r['env'], r['channel'], r['mode'], r['events']) for r in odd), [('unknown', 'a', '', 1), ('unknown', 'a|b', '', 1)])
        _, token, _ = self.guest()
        self.assertEqual(self.rebuild(day, token=token)[0], 401)
        self.assertEqual(self.rebuild(day, token='')[0], 401)
        for first_day, last_day in [('2026-02-30', '2026-03-01'), ('x', 'y'), (next_day, day), (kst_day(-200), kst_day(-1))]:
            self.assertEqual(self.request('/api/stone-match/admin/metrics/rebuild', {'from': str(first_day), 'to': str(last_day)}, self.admin)[0], 400)
        code, result = self.rebuild(kst_day(-95), kst_day(0))
        self.assertEqual(code, 200)
        self.assertEqual(set(result['skipped']) & {str(kst_day(0)), str(kst_day(-95)), str(kst_day(-91))}, {str(kst_day(0)), str(kst_day(-95)), str(kst_day(-91))})
        self.assertIn(str(kst_day(-89)), result['rebuilt'])

    def test_21_unaggregated_old_raw_gets_partial_aggregate_before_purge(self):
        # First deploy / long job outage: raw past the cutoff that was never aggregated.
        now = dt.datetime.now(UTC)
        ms = int(now.timestamp() * 1000)
        cutoff = now - dt.timedelta(days=90)
        missed, admin_day = kst_day(-95), kst_day(-97)
        _, _, player = self.guest()
        for day, count in [(missed, 3), (admin_day, 2)]:
            for n in range(count):
                self.insert('sm_events', dict(self.row(), player=player, created_at=at(day, 10, n)))
        boundary = cutoff.astimezone(KST).date()
        start = dt.datetime(boundary.year, boundary.month, boundary.day, tzinfo=KST).astimezone(UTC)
        before_cutoff, after_cutoff = start + (cutoff - start) / 2, cutoff + (start + dt.timedelta(days=1) - cutoff) / 2
        for created in [before_cutoff, after_cutoff]:
            self.insert('sm_events', dict(self.row(), player=player, created_at=iso(created)))
        existing_boundary = self.metrics(boundary)
        # Admin supplement: once, as partial; never over an existing aggregate.
        code, result = self.rebuild(admin_day, missed)
        self.assertEqual(code, 200)
        self.assertEqual(result['partial'], [str(admin_day), str(missed)])
        self.assertIn(str(missed - dt.timedelta(days=1)), result['skipped'])
        self.assertEqual(self.rebuild(missed)[1], {'rebuilt': [], 'partial': [], 'skipped': [str(missed)]})
        # Undo only the missed day's aggregate so the nightly path is exercised too.
        for row in self.records('sm_daily_metrics', 'day = "%s"' % missed):
            self.request('/api/collections/sm_daily_metrics/records/' + row['id'], token=self.admin, method='DELETE')
        admin_rows = self.metrics(admin_day)
        self.assertEqual(self.request('/api/test-only', {'operation': 'purge', 'kind': 'events', 'ms': ms}, self.admin)[0], 200)
        d = self.metrics(missed)['day|%s|*|*|*|*|*' % missed]
        self.assertEqual((d['raw_rows'], d['events'], d['players'], d['completeness']), (3, 3, 1, 'partial'))
        self.assertEqual(self.metrics(admin_day), admin_rows)
        b = self.metrics(boundary)
        if existing_boundary:  # an earlier test's purge already aggregated this day: must be preserved as-is
            self.assertEqual(b, existing_boundary)
        else:
            self.assertEqual((b['day|%s|*|*|*|*|*' % boundary]['raw_rows'] >= 2, b['day|%s|*|*|*|*|*' % boundary]['completeness']), (True, 'partial'))
        self.assertEqual(self.records('sm_events', 'player = "%s" && created_at < "%s"' % (player, iso(cutoff))), [])
        self.assertEqual(len(self.records('sm_events', 'player = "%s"' % player)), 1)  # after-cutoff row of the boundary day
        # Rerun: nothing overwritten, boundary day kept even though raw rows of it remain.
        snapshot = {day: self.metrics(day) for day in [missed, admin_day, boundary]}
        self.assertEqual(self.request('/api/test-only', {'operation': 'purge', 'kind': 'events', 'ms': ms + 60000}, self.admin)[0], 200)
        self.assertEqual({day: self.metrics(day) for day in snapshot}, snapshot)
        # A fresh boundary day whose remaining rows are all after the cutoff is still captured (it can never
        # become complete) and those rows stay until they themselves pass the cutoff.
        later = ms + 3 * 86400000
        cut2 = dt.datetime.fromtimestamp(later / 1000, UTC) - dt.timedelta(days=90)
        day2 = cut2.astimezone(KST).date()
        end2 = dt.datetime(day2.year, day2.month, day2.day, tzinfo=KST).astimezone(UTC) + dt.timedelta(days=1)
        for row in self.records('sm_daily_metrics', 'day = "%s"' % day2):  # simulate: never aggregated
            self.request('/api/collections/sm_daily_metrics/records/' + row['id'], token=self.admin, method='DELETE')
        self.insert('sm_events', dict(self.row(), player=player, created_at=iso(cut2 + (end2 - cut2) / 2)))
        self.assertEqual(self.request('/api/test-only', {'operation': 'purge', 'kind': 'events', 'ms': later}, self.admin)[0], 200)
        d2 = self.metrics(day2)['day|%s|*|*|*|*|*' % day2]
        self.assertEqual((d2['raw_rows'], d2['completeness']), (1, 'partial'))
        self.assertEqual(len(self.records('sm_events', 'player = "%s" && created_at >= "%s"' % (player, iso(cut2)))), 1)

    def test_22_nightly_window_and_players_purge_protection(self):
        ms = int(time.time() * 1000)
        _, _, player = self.guest()
        # Day D is recomputed through D+8 04:00 KST (index 7 of the complete days); older retained days are not.
        eighth, ninth = kst_day(-8), kst_day(-9)
        self.request('/api/test-only', {'operation': 'purge', 'kind': 'events', 'ms': ms}, self.admin)
        before = {d: self.metrics(d)['day|%s|*|*|*|*|*' % d]['raw_rows'] for d in [eighth, ninth]}
        for d in [eighth, ninth]:
            self.insert('sm_events', dict(self.row(), player=player, created_at=at(d, 9)))
        self.request('/api/test-only', {'operation': 'purge', 'kind': 'events', 'ms': ms}, self.admin)
        after = {d: self.metrics(d)['day|%s|*|*|*|*|*' % d]['raw_rows'] for d in [eighth, ninth]}
        self.assertEqual((after[eighth] - before[eighth], after[ninth] - before[ninth]), (1, 0))
        # players purge deletes stale players' events: those days are aggregated first even without an events run.
        _, _, stale = self.guest()
        old_day = kst_day(-96)
        old = iso(dt.datetime.now(UTC) - dt.timedelta(days=96))
        self.update('sm_players', stale, {'created_at': old, 'last_active_at': old})
        for n in range(2):
            self.insert('sm_events', dict(self.row(), player=stale, created_at=at(old_day, 8, n)))
        for row in self.records('sm_daily_metrics', 'day = "%s"' % old_day):
            self.request('/api/collections/sm_daily_metrics/records/' + row['id'], token=self.admin, method='DELETE')
        self.assertEqual(self.request('/api/test-only', {'operation': 'purge', 'kind': 'players', 'ms': ms}, self.admin)[0], 200)
        self.assertEqual(self.records('sm_events', 'player = "%s"' % stale), [])
        d = self.metrics(old_day)['day|%s|*|*|*|*|*' % old_day]
        self.assertEqual((d['raw_rows'], d['completeness']), (2, 'partial'))

    def test_99_retention_keeps_aggregates_after_raw_purge(self):
        # Runs last: the far-future purge removes all raw events in this disposable database.
        yesterday = kst_day(-1)
        _, token, player = self.guest()
        self.insert('sm_events', dict(self.row(), player=player, created_at=at(yesterday, 13)))
        self.request('/api/test-only', {'operation': 'purge', 'kind': 'events', 'ms': int(time.time() * 1000)}, self.admin)
        days = [yesterday, kst_day(-10), self.legacy_day]
        first = {day: self.stable(self.metrics(day)) for day in days}
        self.assertGreaterEqual(self.metrics(yesterday)['day|%s|*|*|*|*|*' % yesterday]['players'], 1)
        self.assertEqual(self.request('/api/test-only', {'operation': 'purge', 'kind': 'events', 'ms': int(time.time() * 1000)}, self.admin)[0], 200)
        before = {day: self.metrics(day) for day in days}
        self.assertEqual({d: self.stable(v) for d, v in before.items()}, first)
        future = int((time.time() + 120 * 86400) * 1000)
        started = time.time()
        self.assertEqual(self.request('/api/test-only', {'operation': 'purge', 'kind': 'events', 'ms': future}, self.admin)[0], 200)
        self.assertLess(time.time() - started, 30)
        self.assertEqual(self.records('sm_events', 'created_at < "' + iso() + '"'), [])
        self.assertEqual({d: self.metrics(d) for d in before}, before)  # untouched, including computed_at


if __name__ == '__main__':
    unittest.main(verbosity=2)
