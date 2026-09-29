import copy
import unittest

from admin import AdminError
from import_snapshot import TABLES, run, timestamp, transform


class FakeAdmin:
    def __init__(self, data=None):
        self.data = data or {name: [] for name in TABLES.values()}
        self.calls = []

    def records(self, name):
        return copy.deepcopy(self.data[name])

    def request(self, method, path, body):
        self.calls.append((method, path, body))
        name = path.split('/')[3]
        if method == 'POST':
            self.data[name].append({'id': str(len(self.data[name])+1), **body})
        else:
            record = next(r for r in self.data[name] if r['id'] == path.split('/')[-1])
            record.update(body)


def sample():
    return {'ranking_entries': [{'id': 7, 'user_id': 'legacy-user', 'mode': 'time',
        'name': '기존 기록', 'score': 123, 'created_at': '2026-09-29T20:00:00.123456+09:00',
        'week_start': '2026-09-28'}], 'ad_refill_claims': [], 'game_events': [],
        'app_config': [{'key': 'ranking', 'value': {'list_limit': 30}}]}


class ImportTests(unittest.TestCase):
    def test_utc_precision(self):
        self.assertEqual(timestamp('2026-09-29T20:00:00.123456+09:00'), '2026-09-29T11:00:00.123456Z')
        with self.assertRaises(ValueError):
            timestamp('2026-09-29T11:00:00')

    def test_identity_not_migrated_as_player(self):
        row = transform('ranking_entries', sample()['ranking_entries'][0])
        self.assertEqual(row['player'], '')
        self.assertEqual(row['legacy_user_id'], 'legacy-user')
        self.assertEqual(row['legacy_id'], '7')
        self.assertNotIn('order_seq', row)

    def test_dry_run_no_writes(self):
        admin = FakeAdmin()
        result = run(admin, sample())
        self.assertEqual(admin.calls, [])
        self.assertEqual(result['collections']['sm_rankings']['create'], 1)

    def test_repeat_is_idempotent_preserves_other_records(self):
        admin = FakeAdmin()
        admin.data['sm_rankings'].append({'id': 'live', 'legacy_id': '', 'score': 900, 'order_seq': 10})
        run(admin, sample(), True)
        admin.calls.clear()
        result = run(admin, sample(), True)
        self.assertEqual(admin.calls, [])
        self.assertEqual(len(admin.data['sm_rankings']), 2)
        self.assertTrue(result['source_fields_verified'])

    def test_conflict_blocks_entire_import(self):
        admin = FakeAdmin()
        admin.data['sm_rankings'].append({'id': 'old', **transform('ranking_entries', sample()['ranking_entries'][0]), 'score': 999, 'order_seq': 1})
        with self.assertRaises(AdminError):
            run(admin, sample(), True)
        self.assertEqual(admin.calls, [])

    def test_config_updated_without_touching_unrelated_key(self):
        admin = FakeAdmin()
        admin.data['sm_config'] = [{'id': '1', 'key': 'ranking', 'value': {'list_limit': 5}},
                                   {'id': '2', 'key': 'extra', 'value': {'retain': True}}]
        result = run(admin, sample(), True)
        self.assertEqual(result['collections']['sm_config']['update'], 1)
        self.assertEqual(admin.data['sm_config'][1]['value'], {'retain': True})

    def test_delta_import_allocates_after_new_live_records(self):
        admin = FakeAdmin()
        run(admin, sample(), True)
        admin.data['sm_rankings'].append({'id': 'new-live', 'legacy_id': '', 'order_seq': 8, 'score': 100})
        data = sample()
        added = dict(data['ranking_entries'][0], id=8)
        data['ranking_entries'].append(added)
        result = run(admin, data, True)
        migrated = next(r for r in admin.data['sm_rankings'] if r.get('legacy_id') == '8')
        self.assertEqual(migrated['order_seq'], 9)
        self.assertEqual(result['collections']['sm_rankings']['create'], 1)
        run(admin, data, True)

    def test_duplicate_source_no_write(self):
        data = sample()
        data['ranking_entries'] *= 2
        admin = FakeAdmin()
        with self.assertRaises(AdminError):
            run(admin, data, True)
        self.assertEqual(admin.calls, [])

class CollisionTests(unittest.TestCase):
    def test_order_collision_requeries_and_keeps_source_order(self):
        class Racing(FakeAdmin):
            failures = 0
            def request(self, method, path, body):
                if method == 'POST' and 'sm_rankings' in path and self.failures < 2:
                    self.failures += 1
                    self.data['sm_rankings'].append({'id': 'live'+str(self.failures), 'order_seq': body['order_seq']})
                    raise AdminError('safe', status=400, unique_fields={'order_seq'})
                return super().request(method, path, body)
        admin = Racing()
        data = sample()
        data['ranking_entries'].append(dict(data['ranking_entries'][0], id=8))
        run(admin, data, True)
        self.assertEqual([r['order_seq'] for r in admin.data['sm_rankings'] if r.get('legacy_id')], [3, 4])
        self.assertEqual(run(admin, data, True)['collections']['sm_rankings']['unchanged'], 2)

    def test_retry_bound(self):
        from import_snapshot import MAX_CREATE_ATTEMPTS
        class Always(FakeAdmin):
            attempts = 0
            def request(self, method, path, body):
                self.attempts += 1
                raise AdminError('safe', status=400, unique_fields={'order_seq'})
        admin = Always()
        with self.assertRaises(AdminError):
            run(admin, sample(), True)
        self.assertEqual(admin.attempts, MAX_CREATE_ATTEMPTS)

    def test_concurrent_same_legacy_id_identical_or_different(self):
        for changed in [False, True]:
            class Racing(FakeAdmin):
                def request(self, method, path, body):
                    if 'sm_rankings' in path:
                        record = dict(body, id='other')
                        if changed:
                            record['score'] += 1
                        self.data['sm_rankings'].append(record)
                        raise AdminError('safe', status=400, unique_fields={'legacy_id'})
                    return super().request(method, path, body)
            admin = Racing()
            if changed:
                with self.assertRaises(AdminError):
                    run(admin, sample(), True)
            else:
                result = run(admin, sample(), True)
                self.assertEqual(result['collections']['sm_rankings']['unchanged'], 1)
                self.assertEqual(result['collections']['sm_rankings']['create'], 0)
            self.assertEqual(len(admin.data['sm_rankings']), 1)

    def test_unrelated_errors_are_not_retried(self):
        for error in [AdminError('safe', status=500), AdminError('safe', status=400), AdminError('safe')]:
            class Failure(FakeAdmin):
                attempts = 0
                def request(self, method, path, body):
                    self.attempts += 1
                    raise error
            admin = Failure()
            with self.assertRaises(AdminError):
                run(admin, sample(), True)
            self.assertEqual(admin.attempts, 1)


class AdminErrorTests(unittest.TestCase):
    def test_only_safe_unique_metadata_is_retained(self):
        import io
        import json
        import urllib.error
        from admin import PocketBaseAdmin
        client = PocketBaseAdmin.__new__(PocketBaseAdmin)
        client.base_url = 'http://127.0.0.1:1'
        client.token = None
        class FailedOpener:
            def open(self, *args, **kwargs):
                payload = {'message': 'private value', 'data': {
                    'order_seq': {'code': 'validation_not_unique', 'message': 'private value'},
                    'name': {'code': 'validation_not_unique', 'message': 'private value'}}}
                raise urllib.error.HTTPError('http://127.0.0.1:1', 400, 'bad', {}, io.BytesIO(json.dumps(payload).encode()))
        client.opener = FailedOpener()
        with self.assertRaises(AdminError) as context:
            client.request('POST', '/api/collections/sm_rankings/records', {})
        self.assertEqual(context.exception.status, 400)
        self.assertEqual(context.exception.unique_fields, {'order_seq'})
        self.assertNotIn('private value', str(context.exception))
        self.assertNotIn('private value', repr(context.exception.__dict__))


if __name__ == '__main__':
    unittest.main()
