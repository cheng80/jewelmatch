#!/usr/bin/env python3
"""Supabase 스냅샷을 기존 데이터와 충돌 없이 이전한다. 기본은 dry-run."""
import argparse
import datetime
import hashlib
import json
import sys
from pathlib import Path

from admin import AdminError, PocketBaseAdmin

TABLES = {
    'ranking_entries': 'sm_rankings',
    'ad_refill_claims': 'sm_ad_claims',
    'game_events': 'sm_events',
    'app_config': 'sm_config',
}


def timestamp(value):
    if not value:
        return ''
    date = datetime.datetime.fromisoformat(value.replace('Z', '+00:00'))
    if date.tzinfo is None:
        raise ValueError('Source timestamp missing timezone')
    return date.astimezone(datetime.timezone.utc).isoformat(timespec='microseconds').replace('+00:00', 'Z')


def transform(table, row):
    if table == 'app_config':
        return {'key': row['key'], 'value': row['value']}
    result = {
        'legacy_id': str(row['id']),
        'legacy_user_id': row.get('user_id') or '',
        'created_at': timestamp(row['created_at']),
        'player': '',
    }
    if table == 'ranking_entries':
        result.update({key: row[key] for key in ('mode', 'name', 'score')})
        result['week_start'] = row.get('week_start') or ''
    elif table == 'ad_refill_claims':
        result.update({key: row[key] for key in ('item', 'claim_date')})
    elif table == 'game_events':
        result.update({key: row[key] for key in ('session_id', 'name', 'params', 'app_version', 'channel')})
        result['client_ts'] = timestamp(row.get('client_ts'))
    return result


# 최초 시도를 포함한 상한. 네트워크/서버/다른 검증 오류는 재시도하지 않는다.
MAX_CREATE_ATTEMPTS = 5


def create_historical(admin, collection, expected):
    ranking = collection == 'sm_rankings'
    immutable = {k: v for k, v in expected.items() if k != 'order_seq'}
    for attempt in range(MAX_CREATE_ATTEMPTS):
        rows = admin.records(collection)
        matches = [r for r in rows if r.get('legacy_id') == immutable['legacy_id']]
        if len(matches) > 1:
            raise AdminError(f'Duplicate migration identifier in {collection}')
        if matches:
            if not all(matches[0].get(k) == v for k, v in immutable.items()):
                raise AdminError(f'Concurrent import conflict in {collection}; completed writes are preserved')
            return False
        body = dict(immutable)
        if ranking:
            maximum = max((r.get('order_seq', 0) for r in rows), default=0)
            if not isinstance(maximum, int) or isinstance(maximum, bool) or maximum >= 9007199254740991:
                raise AdminError('Invalid or exhausted ranking order sequence')
            body['order_seq'] = maximum + 1
        try:
            admin.request('POST', f'/api/collections/{collection}/records', body)
            return True
        except AdminError as error:
            allowed = {'legacy_id', 'order_seq'} if ranking else {'legacy_id'}
            if error.status != 400 or not error.unique_fields or not error.unique_fields <= allowed:
                raise
            if attempt + 1 == MAX_CREATE_ATTEMPTS:
                # 마지막 충돌이 동일 legacy_id의 성공한 동시 import일 수도 있다.
                matches = [r for r in admin.records(collection) if r.get('legacy_id') == immutable['legacy_id']]
                if len(matches) == 1 and all(matches[0].get(k) == v for k, v in immutable.items()):
                    return False
                raise AdminError(f'Concurrent import retry limit reached in {collection}; rerun safely') from None
    raise AssertionError('Unreachable')


def run(admin, snapshot, apply=False):
    operations = []
    summary = {}
    for table, collection in TABLES.items():
        key = 'key' if table == 'app_config' else 'legacy_id'
        existing = {}
        for row in admin.records(collection):
            identity = row.get(key)
            if identity:
                if identity in existing:
                    raise AdminError(f'Duplicate migration identifier in {collection}')
                existing[identity] = row
        counts = {'source': len(snapshot[table]), 'create': 0, 'update': 0, 'unchanged': 0}
        seen = set()
        source_rows = snapshot[table]
        next_order = 0
        if table == 'ranking_entries':
            # 원본 ID는 legacy_id에 보존한다. PB 순번은 기존 신규 기록과 공유한다.
            all_ranks = admin.records(collection)
            next_order = max((row.get('order_seq', 0) for row in all_ranks), default=0)
            source_rows = sorted(source_rows, key=lambda row: int(row['id']))
        for source in source_rows:
            body = transform(table, source)
            identity = body[key]
            if identity in seen:
                raise AdminError(f'Duplicate source identifier in {table}')
            seen.add(identity)
            target = existing.get(identity)
            if table == 'ranking_entries':
                if target is not None:
                    body['order_seq'] = target['order_seq']
                else:
                    next_order += 1
                    body['order_seq'] = next_order
            if target is None:
                counts['create'] += 1
                operations.append(('POST', f'/api/collections/{collection}/records', body))
            elif all(target.get(field) == value for field, value in body.items()):
                counts['unchanged'] += 1
            elif table == 'app_config':
                counts['update'] += 1
                operations.append(('PATCH', f'/api/collections/{collection}/records/{target["id"]}', body))
            else:
                raise AdminError(f'Source and existing {collection} record differ; no changes applied')
        summary[collection] = counts
    # 모든 데이터를 먼저 검사해 충돌이 있으면 쓰지 않는다.
    if apply:
        for method, path, body in operations:
            collection = path.split('/')[3]
            if method == 'POST' and collection != 'sm_config':
                if not create_historical(admin, collection, body):
                    summary[collection]['create'] -= 1
                    summary[collection]['unchanged'] += 1
            else:
                admin.request(method, path, body)
        # 원본의 모든 필드를 확인한다. 추가 운영 기록은 삭제하지 않는다.
        for table, collection in TABLES.items():
            key = 'key' if table == 'app_config' else 'legacy_id'
            rows = {r.get(key): r for r in admin.records(collection) if r.get(key)}
            for source in snapshot[table]:
                expected = transform(table, source)
                actual = rows.get(expected[key], {})
                if not all(actual.get(k) == v for k, v in expected.items()):
                    raise AdminError(f'Post-import verification failed for {collection}')
    return {'mode': 'apply' if apply else 'dry-run', 'collections': summary,
            'source_fields_verified': apply, 'users_imported': 0}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--env-file', default='.env.pocketbase')
    parser.add_argument('--snapshot', required=True)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--report', required=True)
    args = parser.parse_args()
    path = Path(args.snapshot)
    snapshot = json.loads(path.read_text())
    if 'rows' in snapshot:
        snapshot = snapshot['rows'][0]['snapshot']
    if not all(isinstance(snapshot.get(k), list) for k in TABLES):
        raise AdminError('Invalid snapshot structure')
    result = run(PocketBaseAdmin.from_env(args.env_file), snapshot, args.apply)
    result['source_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    report = Path(args.report)
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (AdminError, ValueError, KeyError) as error:
        # 입력 내용이나 사용자 행을 포함할 수 있는 예외 상세는 출력하지 않는다.
        print(str(error) if isinstance(error, AdminError) else 'Invalid migration input', file=sys.stderr)
        sys.exit(1)
