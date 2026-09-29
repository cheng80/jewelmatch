#!/usr/bin/env bash
set -euo pipefail
# 앱 빌드에는 공개 URL 설정만 넣는다. .env.pocketbase의 관리자 정보는 읽지 않는다.
# 설정이 없으면 빈 출력으로 로컬 플레이 빌드가 된다. 운영 빌드는 --required로 필수 확인한다.
# config/supabase.json은 읽지 않는다.
config=config/pocketbase.json
if [[ ! -f "$config" ]]; then
  if [[ "${1:-}" == '--required' ]]; then
    echo "${config}이 필요합니다." >&2
    exit 1
  fi
  exit 0
fi
# 파일이 있으면 dev에서도 검사한다. 오류 문구에 설정 값은 출력하지 않는다.
python3 - "$config" <<'PY'
import json, sys
from urllib.parse import urlsplit

path = sys.argv[1]
def fail(reason):
    sys.exit(f'{path}: {reason}')
try:
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
except (OSError, ValueError):
    fail('올바른 JSON이 아닙니다.')
if not isinstance(data, dict) or set(data) != {'POCKETBASE_URL'}:
    fail('POCKETBASE_URL 키 하나만 둘 수 있습니다(관리자 정보 금지).')
url = data['POCKETBASE_URL']
if not isinstance(url, str) or not url or any(c.isspace() or ord(c) < 32 for c in url):
    fail('POCKETBASE_URL 값이 비었거나 공백을 포함합니다.')
try:
    parts = urlsplit(url)
    host = parts.hostname
except ValueError:
    fail('POCKETBASE_URL을 해석할 수 없습니다.')
if parts.scheme != 'https' or not host:
    fail('POCKETBASE_URL은 https 주소여야 합니다.')
if '@' in parts.netloc:
    fail('POCKETBASE_URL에 계정 정보를 넣을 수 없습니다.')
if parts.query or parts.fragment or '?' in url or '#' in url:
    fail('POCKETBASE_URL에 query나 fragment를 넣을 수 없습니다.')
PY
printf '%s\n' "--dart-define-from-file=$config"
