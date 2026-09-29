"""tools/ga4_define.sh와 tools/deploy_match_web.sh의 GA4 연결 회귀.

실제 config/ga4.json, flutter, 네트워크는 쓰지 않는다. tmp/ 아래 합성 fixture와 가짜 실행 파일만 쓴다.
배포 스크립트 종단 시험은 sentry_web_build_test.py의 합성 루트와 가짜 flutter/sentry/curl을 재사용한다.
실행: python3 test/tools/ga4_define_test.py
"""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import sentry_web_build_test as sw  # noqa: E402

SCRIPT = ROOT / 'tools' / 'ga4_define.sh'
TMP = ROOT / 'tmp' / 'ga4-integration-20260929'
sw.TMP = TMP
OK = '--dart-define-from-file=config/ga4.json\n'
PROD, TEST = 'G-ABCDE12345', 'G-QATEST9999'


def run(config, *args):
    TMP.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=TMP) as cwd:
        (Path(cwd) / 'config').mkdir()
        if config is not None:
            body = config if isinstance(config, str) else json.dumps(config)
            (Path(cwd) / 'config' / 'ga4.json').write_text(body, encoding='utf-8')
        r = subprocess.run(['bash', str(SCRIPT), *args], cwd=cwd, capture_output=True, text=True)
        return r.returncode, r.stdout, r.stderr


def test_define_script():
    # 없으면 비활성(빈 출력), example 파일은 읽지 않는다
    assert run(None) == (0, '', '')
    # 운영만, 운영과 QA(비어도 허용, 다르면 허용)
    assert run({'GA4_MEASUREMENT_ID': PROD}) == (0, OK, '')
    assert run({'GA4_MEASUREMENT_ID': PROD, 'GA4_TEST_MEASUREMENT_ID': ''}) == (0, OK, '')
    assert run({'GA4_MEASUREMENT_ID': PROD, 'GA4_TEST_MEASUREMENT_ID': TEST}) == (0, OK, '')
    secret = 'sk-secret-value'
    bad = [
        '{not json', '[]', '"G-ABC"', {}, {'GA4_TEST_MEASUREMENT_ID': TEST},
        {'GA4_MEASUREMENT_ID': ''}, {'GA4_MEASUREMENT_ID': None}, {'GA4_MEASUREMENT_ID': 1},
        {'GA4_MEASUREMENT_ID': 'g-abcde12345'}, {'GA4_MEASUREMENT_ID': 'G-'},
        {'GA4_MEASUREMENT_ID': 'G-AB CD'}, {'GA4_MEASUREMENT_ID': ' G-ABCDE12345'},
        {'GA4_MEASUREMENT_ID': 'G-ABCDE12345\n'}, {'GA4_MEASUREMENT_ID': 'UA-12345-1'},
        {'GA4_MEASUREMENT_ID': 'G-ABC-DEF'}, {'GA4_MEASUREMENT_ID': 'G-abcde12345'},
        {'GA4_MEASUREMENT_ID': PROD, 'GA4_TEST_MEASUREMENT_ID': 'bad'},
        {'GA4_MEASUREMENT_ID': PROD, 'GA4_TEST_MEASUREMENT_ID': 5},
        {'GA4_MEASUREMENT_ID': PROD, 'GA4_TEST_MEASUREMENT_ID': None},
        {'GA4_MEASUREMENT_ID': PROD, 'GA4_TEST_MEASUREMENT_ID': PROD},  # 운영과 QA 같음
        {'GA4_MEASUREMENT_ID': PROD, 'GA4_API_SECRET': secret},  # 인증 값
        {'GA4_MEASUREMENT_ID': PROD, 'API_SECRET': secret},
        {'GA4_MEASUREMENT_ID': PROD, 'GA4_TEST_MEASUREMENT_ID': TEST, 'extra': 1},
    ]
    for config in bad:
        code, out, err = run(config)
        assert code != 0 and out == '', config
        # 오류 문구에 설정 값이 없다
        for value in (PROD, TEST, secret):
            assert value not in err, (config, err)


def test_deploy_script():
    def build(config, *flags, sentry=True):
        with sw.workdir() as w:
            work = Path(w)
            root = sw.make_root(work, env_text=sw.ENV_OK if sentry else None)
            sw.fake_bin(work)
            shutil.copy(SCRIPT, root / 'tools')
            if config is not None:
                (root / 'config' / 'ga4.json').write_text(
                    config if isinstance(config, str) else json.dumps(config))
            (code, text), out = sw.deploy(work, root, 'ok', *flags)
            flutter = work / 'flutter.json'
            args = json.loads(flutter.read_text()) if flutter.exists() else None
            return code, text, args, (work / 'sentry.log.curl').exists(), sw.calls(work), out.name

    ga4 = '--dart-define-from-file=config/ga4.json'
    backend = '--dart-define-from-file=config/pocketbase.json'
    cfg = {'GA4_MEASUREMENT_ID': PROD, 'GA4_TEST_MEASUREMENT_ID': TEST}

    # 1) 설정 있음 + Sentry 활성: GA4, backend, Sentry define 모두 flutter에 전달, source map과 배포는 종전대로
    code, text, args, deployed, sentry_calls, _ = build(cfg)
    assert code == 0 and deployed, text
    assert ga4 in args and backend in args and '--source-maps' in args and '--wasm' in args, args
    assert any(a.startswith('--dart-define-from-file=') and a.endswith('sentry-defines.json') for a in args)
    assert len(sentry_calls) == 1
    assert args.index(backend) < args.index(ga4)
    assert 'ga4: enabled' in text
    for value in (PROD, TEST):
        assert value not in text, 'GA4 값 출력'
    # define 파일 내용은 flutter가 읽으므로 스크립트가 값을 복사해 쓰지 않는다(경로만 전달)
    assert not [a for a in args if PROD in a or TEST in a]

    # 2) 운영 ID만 있는 설정
    code, text, args, deployed, _, _ = build({'GA4_MEASUREMENT_ID': PROD}, sentry=False)
    assert code == 0 and ga4 in args and deployed, text

    # 3) 설정 없음: 비활성, GA4 define 없음, 기존 빌드와 같음(backend, Sentry 유지)
    code, text, args, deployed, sentry_calls, _ = build(None)
    assert code == 0 and deployed, text
    assert ga4 not in args and backend in args and '--source-maps' in args
    assert len(sentry_calls) == 1 and 'ga4: disabled' in text

    # 4) --no-ga4: 설정이 있어도 GA4 define 없음. 잘못된 설정이어도 읽지 않는다
    for config in (cfg, '{broken'):
        code, text, args, deployed, _, _ = build(config, '--no-ga4', sentry=False)
        assert code == 0 and deployed, text
        assert ga4 not in args and backend in args

    # 5) 잘못된 설정(형식, 운영과 QA 같음, 인증 값 키): flutter, sentry, 배포 모두 실행 안 함
    secret = 'sk-secret-value'
    for config in (
        {'GA4_MEASUREMENT_ID': 'G-bad!'},
        {'GA4_MEASUREMENT_ID': PROD, 'GA4_TEST_MEASUREMENT_ID': PROD},
        {'GA4_MEASUREMENT_ID': PROD, 'GA4_API_SECRET': secret},
        '{broken',
    ):
        code, text, args, deployed, sentry_calls, out_name = build(config)
        assert code != 0, config
        assert args is None and not deployed and sentry_calls == [], config
        for value in (PROD, secret):
            assert value not in text, config

    # 6) Sentry 없이(--no-sentry) GA4만 켜도 동작
    code, text, args, deployed, sentry_calls, _ = build(cfg, '--no-sentry')
    assert code == 0 and ga4 in args and '--source-maps' not in args and sentry_calls == [], text


def test_repo_files():
    example = json.loads((ROOT / 'config' / 'ga4.example.json').read_text())
    assert set(example) == {'GA4_MEASUREMENT_ID', 'GA4_TEST_MEASUREMENT_ID'}
    assert example['GA4_TEST_MEASUREMENT_ID'] == ''
    # example의 자리표시자는 실제 ID 형식이 아니다(그대로 복사해 쓰면 검증이 막는다)
    assert run(example)[0] != 0
    ignored = subprocess.run(['git', 'check-ignore', '-q', 'config/ga4.json'], cwd=ROOT)
    assert ignored.returncode == 0, 'config/ga4.json은 Git 제외여야 한다'
    tracked = subprocess.run(['git', 'check-ignore', '-q', 'config/ga4.example.json'], cwd=ROOT)
    assert tracked.returncode != 0, 'example은 제외되면 안 된다'


if __name__ == '__main__':
    for name, fn in sorted(globals().items()):
        if name.startswith('test_'):
            fn()
            print(f'ok {name}')
    print('all ok')
