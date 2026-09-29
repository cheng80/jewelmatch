"""package.json 빌드 진입점이 backend_define.sh 실패 시 Flutter를 실행하지 않는지 확인한다.

실제 npm으로 스크립트를 돌리되 flutter/node는 기록만 하는 가짜로 바꾼다.
fixture는 tmp/ 아래 임시 폴더이며 실제 config는 읽지 않는다.
실행: python3 test/tools/package_scripts_test.py
"""
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TMP = ROOT / 'tmp' / 'pocketbase-followup-20260929'
DEFINE = '--dart-define-from-file=config/pocketbase.json'
GOOD = {'POCKETBASE_URL': 'https://pb.example'}
BAD = {'POCKETBASE_URL': 'http://pb.example'}
PROD_ENV = {'INTOSS_REWARDED_AD_GROUP_ID': 'r', 'INTOSS_BANNER_AD_GROUP_ID': 'b'}


def run(script, config, env=None):
    TMP.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=TMP) as cwd:
        work = Path(cwd)
        (work / 'tools').mkdir()
        (work / 'bin').mkdir()
        shutil.copy(ROOT / 'package.json', work)
        shutil.copy(ROOT / 'tools' / 'backend_define.sh', work / 'tools')
        (work / 'config').mkdir()
        if config is not None:
            (work / 'config' / 'pocketbase.json').write_text(json.dumps(config))
        log = work / 'calls.log'
        fakes = {
            'flutter': f'echo "flutter $*" >> "{log}"',
            # npm 자체도 node로 실행되므로 광고 브리지 준비만 가로챈다.
            'node': f'[ "$1" = tools/prepare_intoss_web.mjs ] && '
                    f'exec echo "node $*" >> "{log}"\nexec "{shutil.which("node")}" "$@"',
        }
        for name, body in fakes.items():
            fake = work / 'bin' / name
            fake.write_text(f'#!/bin/sh\n{body}\n')
            fake.chmod(0o755)
        full_env = {k: v for k, v in os.environ.items() if not k.startswith('INTOSS_')}
        full_env.update(env or {})
        full_env['PATH'] = f"{work / 'bin'}:{full_env['PATH']}"
        r = subprocess.run(['npm', 'run', '--silent', script], cwd=cwd,
                           env=full_env, capture_output=True, text=True)
        calls = log.read_text().splitlines() if log.exists() else []
        return r.returncode, calls


def flutter(calls):
    return [c for c in calls if c.startswith('flutter ')]


def main():
    for script in ('dev:ads', 'build:flutter:intoss:test'):
        # 정상 설정: 공개 URL define 전달
        code, calls = run(script, GOOD)
        assert code == 0 and len(flutter(calls)) == 1, (script, code, calls)
        assert flutter(calls)[0].endswith(DEFINE), calls
        # 설정 없음: backend 없는 dev/test 빌드 허용
        code, calls = run(script, None)
        assert code == 0 and len(flutter(calls)) == 1, (script, code, calls)
        assert 'dart-define-from-file' not in flutter(calls)[0], calls
        # 잘못된 설정: Flutter 실행 전에 실패
        code, calls = run(script, BAD)
        assert code != 0 and calls == [], (script, code, calls)
    # test 빌드는 성공 시에만 광고 브리지 준비까지 간다.
    assert run('build:flutter:intoss:test', GOOD)[1][-1].startswith('node ')
    # production guard 보존: 설정 없음/잘못됨/광고 ID 없음 거절
    for config, env in ((None, PROD_ENV), (BAD, PROD_ENV), (GOOD, {})):
        code, calls = run('build:flutter:intoss', config, env)
        assert code != 0 and calls == [], (config, env, code, calls)
    code, calls = run('build:flutter:intoss', GOOD, PROD_ENV)
    assert code == 0 and flutter(calls)[0].endswith(DEFINE), calls
    print('package scripts: 11 cases passed')


if __name__ == '__main__':
    main()
