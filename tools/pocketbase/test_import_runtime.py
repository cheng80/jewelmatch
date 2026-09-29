"""Local PB 0.39.7 import tests. Source rows, secrets and response bodies are never printed."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

from admin import AdminError, PocketBaseAdmin
from import_snapshot import TABLES, run

ROOT = Path(__file__).resolve().parents[2]


class RuntimeImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('local_pb_fixture', ROOT / 'test/pocketbase/integration_test.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        cls.fixture = module.PocketBaseIntegration
        cls.fixture.setUpClass()
        cls.admin = PocketBaseAdmin(cls.fixture.base, cls.fixture.email, cls.fixture.password)

    @classmethod
    def tearDownClass(cls):
        cls.fixture.tearDownClass()

    def test_full_snapshot_racing_rank_and_repeat(self):
        source = json.loads((ROOT / 'tmp/pocketbase-migration-20260929/source-snapshot.json').read_text())
        if 'rows' in source:
            source = source['rows'][0]['snapshot']
        self.assertTrue(all(isinstance(source.get(k), list) for k in TABLES), 'snapshot structure')
        admin = self.admin
        class RacingAdmin:
            raced = False
            def records(self, collection):
                return admin.records(collection)
            def request(self, method, path, body):
                if not self.raced and method == 'POST' and '/sm_rankings/' in path:
                    self.raced = True
                    # A second real HTTP writer takes the sequence after importer reads MAX.
                    live = dict(body, legacy_id='', legacy_user_id='', name='local_concurrent', score=1)
                    admin.request(method, path, live)
                return admin.request(method, path, body)
        proxy = RacingAdmin()
        first = run(proxy, source, True)
        self.assertTrue(proxy.raced)
        self.assertTrue(first['source_fields_verified'])
        after_first = {name: admin.records(name) for name in TABLES.values()}
        second = run(admin, source, True)
        self.assertTrue(second['source_fields_verified'])
        self.assertTrue(all(c['create'] == 0 and c['update'] == 0 for c in second['collections'].values()))
        after_second = {name: admin.records(name) for name in TABLES.values()}
        self.assertTrue(after_first == after_second, 'rerun altered records')
        self.assertTrue(self.fixture.existing_users == admin.records('users'), 'users modified')
        self.assertTrue(self.fixture.existing_tasks == admin.records('tasks'), 'tasks modified')
        ranks = [r for r in after_second['sm_rankings'] if r.get('legacy_id')]
        ranks.sort(key=lambda r: int(r['legacy_id']))
        self.assertTrue(all(a['order_seq'] < b['order_seq'] for a, b in zip(ranks, ranks[1:])), 'source tie ordering')
        changed = copy.deepcopy(source)
        changed['ranking_entries'][0]['score'] += 1
        with self.assertRaises(AdminError):
            run(admin, changed, True)
        self.assertTrue(after_second == {name: admin.records(name) for name in TABLES.values()}, 'conflict altered records')
        report = {'runtime': '0.39.7', 'first': first, 'repeat': second,
                  'real_http_sequence_collision_recovered': True, 'different_source_rejected': True,
                  'users_tasks_unchanged': True, 'source_order_preserved': True}
        (ROOT / 'tmp/pocketbase-migration-20260929/importer-runtime-report.json').write_text(json.dumps(report, indent=2)+'\n')

    def test_racing_identical_legacy_and_mismatch(self):
        # Synthetic data keeps failure diagnostics independent from the private snapshot.
        from test_import_snapshot import sample
        for conflict in [False, True]:
            data = sample()
            data['ranking_entries'][0]['id'] = 900001 + int(conflict)
            admin = self.admin
            class RacingAdmin:
                raced = False
                def records(self, collection):
                    return admin.records(collection)
                def request(self, method, path, body):
                    if not self.raced and method == 'POST' and '/sm_rankings/' in path:
                        self.raced = True
                        inserted = dict(body)
                        if conflict:
                            inserted['score'] += 1
                        admin.request(method, path, inserted)
                    return admin.request(method, path, body)
            if conflict:
                with self.assertRaises(AdminError):
                    run(RacingAdmin(), data, True)
            else:
                result = run(RacingAdmin(), data, True)
                self.assertEqual(result['collections']['sm_rankings']['unchanged'], 1)
                self.assertEqual(result['collections']['sm_rankings']['create'], 0)
