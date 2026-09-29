#!/usr/bin/env python3
"""PocketBase 관리 API. 자격정보와 응답 토큰은 출력하거나 파일에 저장하지 않는다."""
import json
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


class AdminError(RuntimeError):
    def __init__(self, message, *, status=None, unique_fields=()):
        super().__init__(message)
        self.status = status
        self.unique_fields = frozenset(unique_fields)


def read_env(path):
    values = {}
    for line in Path(path).read_text().splitlines():
        if not line.strip() or line.lstrip().startswith('#') or '=' not in line:
            continue
        key, value = line.split('=', 1)
        value = value.strip()
        if len(value) > 1 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[key.strip()] = value
    return values


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


class PocketBaseAdmin:
    def __init__(self, base_url, email, password):
        self.base_url = base_url.rstrip('/')
        parsed = urllib.parse.urlparse(self.base_url)
        if parsed.username or parsed.password or parsed.query or parsed.fragment:
            raise AdminError('Invalid PocketBase URL')
        if parsed.scheme != 'https' and not (
            parsed.scheme == 'http' and parsed.hostname in ('127.0.0.1', 'localhost')
        ):
            raise AdminError('HTTPS required outside localhost')
        self.opener = urllib.request.build_opener(NoRedirect)
        self.token = None
        result = self.request('POST', '/api/collections/_superusers/auth-with-password', {
            'identity': email, 'password': password,
        })
        self.token = result.get('token')
        if not self.token:
            raise AdminError('No administrator token returned')

    @classmethod
    def from_env(cls, path):
        env = read_env(path)
        keys = ('POCKETBASE_URL', 'POCKETBASE_ADMIN_EMAIL', 'POCKETBASE_ADMIN_PASSWORD')
        if not all(env.get(key) for key in keys):
            raise AdminError('Required PocketBase environment variable missing')
        return cls(*(env[key] for key in keys))

    def request(self, method, path, data=None):
        if not path.startswith('/api/'):
            raise AdminError('Unexpected API path')
        headers = {'User-Agent': 'Mozilla/5.0 StoneMatchMigration', 'Content-Type': 'application/json'}
        if self.token:
            headers['Authorization'] = self.token
        req = urllib.request.Request(
            self.base_url + path, method=method, headers=headers,
            data=None if data is None else json.dumps(data, ensure_ascii=False).encode(),
        )
        try:
            with self.opener.open(req, timeout=30) as response:
                raw = response.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            # 서버 응답은 사용자 데이터나 인증 정보를 포함할 수 있어 기록하지 않는다.
            unique_fields = set()
            if error.code == 400:
                try:
                    details = json.loads(error.read(16384)).get('data', {})
                    for field in ('order_seq', 'legacy_id'):
                        if isinstance(details.get(field), dict) and details[field].get('code') == 'validation_not_unique':
                            unique_fields.add(field)
                except (ValueError, AttributeError, TypeError):
                    pass
            raise AdminError(f'{method} API request failed (HTTP {error.code})',
                             status=error.code, unique_fields=unique_fields) from None
        except (urllib.error.URLError, TimeoutError):
            raise AdminError('PocketBase connection failed') from None

    def records(self, collection):
        page = 1
        rows = []
        while True:
            result = self.request('GET', f'/api/collections/{collection}/records?page={page}&perPage=200')
            rows.extend(result['items'])
            if page >= result['totalPages']:
                return rows
            page += 1
