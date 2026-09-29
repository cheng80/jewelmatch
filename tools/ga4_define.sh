#!/usr/bin/env bash
set -euo pipefail
# GA4 측정 ID는 공개 값이지만 저장소에는 두지 않는다. config/ga4.json(Git 제외)만 읽는다.
# 파일이 없으면 빈 출력(GA4 비활성). 있으면 GA4_MEASUREMENT_ID 필수, GA4_TEST_MEASUREMENT_ID 선택.
# 다른 키와 인증 값은 거절한다. 오류 문구에 설정 값은 출력하지 않는다.
config=config/ga4.json
[[ -f "$config" ]] || exit 0
python3 - "$config" <<'PY'
import json, re, sys

path = sys.argv[1]
def fail(reason):
    sys.exit(f'{path}: {reason}')
try:
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
except (OSError, ValueError):
    fail('올바른 JSON이 아닙니다.')
allowed = {'GA4_MEASUREMENT_ID', 'GA4_TEST_MEASUREMENT_ID'}
if not isinstance(data, dict) or 'GA4_MEASUREMENT_ID' not in data or not set(data) <= allowed:
    fail('GA4_MEASUREMENT_ID 필수, GA4_TEST_MEASUREMENT_ID만 선택입니다(다른 키와 인증 값 금지).')
pattern = re.compile(r'G-[A-Z0-9]+')
prod = data['GA4_MEASUREMENT_ID']
if not isinstance(prod, str) or not pattern.fullmatch(prod):
    fail('GA4_MEASUREMENT_ID 형식이 올바르지 않습니다(G-로 시작하는 대문자와 숫자).')
test = data.get('GA4_TEST_MEASUREMENT_ID', '')
if not isinstance(test, str) or (test and not pattern.fullmatch(test)):
    fail('GA4_TEST_MEASUREMENT_ID 형식이 올바르지 않습니다(비워 두거나 G-로 시작).')
if test == prod:
    fail('GA4_TEST_MEASUREMENT_ID는 운영 ID와 달라야 합니다.')
PY
printf '%s\n' "--dart-define-from-file=$config"
