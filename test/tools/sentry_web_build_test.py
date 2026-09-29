"""tools/sentry_web_build.py와 tools/deploy_match_web.sh의 Sentry 연결 회귀.

실제 sentry CLI, flutter, 네트워크, 실제 .env.sentry는 쓰지 않는다. tmp/ 아래 합성 fixture와
PATH의 가짜 실행 파일(sentry, flutter, dart, curl)만 쓴다.
실행: python3 test/tools/sentry_web_build_test.py
"""
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TMP = ROOT / 'tmp' / 'sentry-integration-20260929'
TOOL = ROOT / 'tools' / 'sentry_web_build.py'
DSN = 'https://publickey123@o1.ingest.example.io/4512169889038416'
TEST_DSN = 'https://testkey456@o1.ingest.example.io/4512169889038999'
TOKEN = 'sntrys_SECRET_TOKEN_VALUE'
ORG, PROJECT = 'org-slug-x', 'project-slug-y'
ENV_OK = (f'SENTRY_DSN={DSN}\nSENTRY_ORG={ORG}\nSENTRY_PROJECT={PROJECT}\n'
          f'SENTRY_AUTH_TOKEN={TOKEN}\nSENTRY_TEST_DSN=\n')
SECRETS = (TOKEN, ORG, PROJECT)

# 가짜 sentry: 호출을 기록하고, 모드에 따라 debug ID를 주입하거나 실패한다.
FAKE_SENTRY = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
log = Path(os.environ['FAKE_LOG'])
proj = os.environ.get('SENTRY_PROJECT', '')
mode = os.environ.get('FAKE_MODE_' + proj.replace('-', '_').upper(), os.environ.get('FAKE_SENTRY_MODE', 'ok'))
args = sys.argv[1:]
rec = {'args': args, 'org': os.environ.get('SENTRY_ORG'), 'project': os.environ.get('SENTRY_PROJECT'),
       'token': os.environ.get('SENTRY_AUTH_TOKEN'), 'dsn': os.environ.get('SENTRY_DSN'),
       'test_project_env': os.environ.get('SENTRY_TEST_PROJECT'), 'cwd': os.getcwd(), 'files': sorted(p.name for p in Path(args[2]).rglob('*') if p.is_file())}
with log.open('a') as f:
    f.write(json.dumps(rec) + '\n')
if mode == 'fail':
    print('boom ' + os.environ.get('SENTRY_ORG', ''), file=sys.stderr)
    sys.exit(1)
if mode == 'mutate':  # 이미 주입된 JS를 다시 바꾸는 CLI(불변 위반)를 흉내낸다
    for js in Path(args[2]).rglob('*.js'):
        with js.open('a') as f:
            f.write('\n//# debugId=11111111-2222-3333-4444-555555555555\n')
if mode == 'ok':
    for js in Path(args[2]).rglob('*.js'):
        if 'debugId=' in js.read_text():  # 실제 CLI처럼 이미 주입된 파일은 건드리지 않는다
            continue
        with js.open('a') as f:
            f.write('\n//# debugId=7b4e8566-5998-4f68-9e22-8ab712e5b66c\n')
        m = Path(str(js) + '.map')
        d = json.loads(m.read_text())
        d['debug_id'] = '7b4e8566-5998-4f68-9e22-8ab712e5b66c'
        m.write_text(json.dumps(d))
'''

# 가짜 flutter: --output에 산출물을 만들고 define 파일의 release를 main.dart.js에 넣는다.
FAKE_FLUTTER = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
Path(os.environ['FAKE_LOG']).with_name('flutter.json').write_text(json.dumps(args))
out = Path(args[args.index('--output') + 1])
release = dsn = ''
for a in args:
    if a.startswith('--dart-define-from-file=') and a.endswith('sentry-defines.json'):
        d = json.loads(Path(a.split('=', 1)[1]).read_text())
        release, dsn = d['SENTRY_RELEASE'], d['SENTRY_DSN']
out.mkdir(parents=True)
(out / 'index.html').write_text('<html></html>')
(out / 'main.dart.js').write_text('var r="%s",d="%s";\n//# sourceMappingURL=main.dart.js.map\n' % (release, dsn))
(out / 'main.dart.mjs').write_text('mjs')
(out / 'main.dart.wasm').write_bytes(b'\0asm')
if '--source-maps' in args:
    (out / 'main.dart.js.map').write_text('{"version":3,"mappings":""}')
    (out / 'main.dart.wasm.map').write_text('{"version":3,"mappings":""}')
'''

FAKE_CURL = r'''#!/usr/bin/env bash
out=""
while [[ $# -gt 0 ]]; do
  [[ "$1" == "-o" ]] && out="$2"
  shift
done
echo curl >> "$FAKE_LOG.curl"
echo '{"result":"OK"}' > "$out"
printf 200
'''


def write_exec(path, body):
    path.write_text(body, encoding='utf-8')
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def make_root(work, env_text=ENV_OK):
    """합성 저장소 루트. 실제 소스와 config는 복사하지 않는다."""
    root = work / 'repo'
    for d in ('lib', 'web', 'tools', 'config'):
        (root / d).mkdir(parents=True)
    (root / 'pubspec.yaml').write_text('name: x\nversion: 1.0.0+1\n')
    (root / 'lib' / 'main.dart').write_text('void main() {}\n')
    (root / 'web' / 'index.html').write_text('<html></html>\n')
    (root / 'config' / 'pocketbase.json').write_text('{"POCKETBASE_URL": "https://pb.example"}')
    for name in ('sentry_web_build.py', 'deploy_match_web.sh', 'backend_define.sh', 'ga4_define.sh'):
        shutil.copy(ROOT / 'tools' / name, root / 'tools')
    if env_text is not None:
        (root / '.env.sentry').write_text(env_text)
    return root


def fake_bin(work):
    b = work / 'bin'
    b.mkdir()
    write_exec(b / 'sentry', FAKE_SENTRY)
    write_exec(b / 'flutter', FAKE_FLUTTER)
    write_exec(b / 'curl', FAKE_CURL)
    write_exec(b / 'dart', '#!/usr/bin/env bash\nexit 0\n')
    return b


def run(cmd, work, mode='ok', extra=None, **kw):
    env = dict(os.environ, PATH=f'{work / "bin"}:{os.environ["PATH"]}', FAKE_LOG=str(work / 'sentry.log'),
               FAKE_SENTRY_MODE=mode, SENTRY_AUTH_TOKEN='parent-env-token', **(extra or {}))
    r = subprocess.run(cmd, cwd=kw.pop('cwd', work), env=env, capture_output=True, text=True, **kw)
    return r.returncode, r.stdout + r.stderr


def calls(work):
    log = work / 'sentry.log'
    return [json.loads(x) for x in log.read_text().splitlines()] if log.exists() else []


def no_secret(text, extra=()):
    for s in SECRETS + tuple(extra) + ('parent-env-token',):
        assert s not in text, 'secret leaked'


def tool(root, *args):
    return ['python3', str(root / 'tools' / 'sentry_web_build.py'), '--root', str(root), *args]


def workdir():
    TMP.mkdir(parents=True, exist_ok=True)
    return tempfile.TemporaryDirectory(dir=TMP, prefix='t-')


def test_define():
    with workdir() as w:
        work = Path(w)
        root = make_root(work)
        fake_bin(work)
        out = work / 'd.json'
        code, text = run(tool(root, 'define', '--out', str(out)), work)
        assert code == 0 and 'enabled' in text, text
        no_secret(text)
        d = json.loads(out.read_text())
        assert set(d) == {'SENTRY_DSN', 'SENTRY_RELEASE'} and d['SENTRY_DSN'] == DSN, d
        rel = d['SENTRY_RELEASE']
        assert rel.startswith('stone-match@1.0.0+1-') and len(rel.split('-')[-1]) == 12, rel
        no_secret(out.read_text())  # define 파일에는 공개 DSN만, 관리자 값 없음
        assert 'publickey123' not in text  # 출력에는 DSN 값도 없음
        # 같은 소스는 같은 release, 소스가 바뀌면 다른 release
        run(tool(root, 'define', '--out', str(work / 'd2.json')), work)
        assert json.loads((work / 'd2.json').read_text()) == d
        (root / 'lib' / 'main.dart').write_text('void main() { /* dirty */ }\n')
        run(tool(root, 'define', '--out', str(work / 'd3.json')), work)
        assert json.loads((work / 'd3.json').read_text())['SENTRY_RELEASE'] != rel
        # 별도 QA DSN은 있을 때만 포함
        (root / '.env.sentry').write_text(ENV_OK.replace('SENTRY_TEST_DSN=', f'SENTRY_TEST_DSN={TEST_DSN}'))
        run(tool(root, 'define', '--out', str(work / 'd4.json')), work)
        d4 = json.loads((work / 'd4.json').read_text())
        assert set(d4) == {'SENTRY_DSN', 'SENTRY_TEST_DSN', 'SENTRY_RELEASE'} and d4['SENTRY_TEST_DSN'] == TEST_DSN


def test_define_disabled_and_failclosed():
    with workdir() as w:
        work = Path(w)
        root = make_root(work, env_text=None)
        out = work / 'd.json'
        # 파일 없음, 값이 모두 빈 템플릿은 비활성(파일 미생성)
        for env in (None, '# c\nSENTRY_DSN=\nSENTRY_ORG=\nSENTRY_PROJECT=\nSENTRY_AUTH_TOKEN=\n'):
            if env is not None:
                (root / '.env.sentry').write_text(env)
            code, text = run(tool(root, 'define', '--out', str(out)), work)
            assert code == 0 and 'disabled' in text and not out.exists(), text
        bad = [
            f'SENTRY_ORG={ORG}\nSENTRY_PROJECT={PROJECT}\n',                       # DSN 없음
            f'SENTRY_DSN={DSN}\nSENTRY_ORG={ORG}\n',                               # PROJECT 없음
            f'SENTRY_DSN={DSN}\nSENTRY_PROJECT={PROJECT}\n',                       # ORG 없음
            ENV_OK.replace('https://', 'http://'),                                # http
            ENV_OK.replace('publickey123@', ''),                                   # 공개키 없음
            ENV_OK.replace('publickey123@', 'publickey123:pw@'),                   # 비밀 키 포함
            ENV_OK.replace('/4512169889038416', '/notnumber'),                     # 프로젝트 번호 아님
            ENV_OK.replace(DSN, DSN + '?x=1'),
            ENV_OK.replace(f'SENTRY_ORG={ORG}', 'SENTRY_ORG=bad slug/'),
            ENV_OK.replace('SENTRY_TEST_DSN=', f'SENTRY_TEST_DSN={DSN}'),          # QA DSN이 운영과 동일
            ENV_OK.replace('SENTRY_TEST_DSN=', 'SENTRY_TEST_DSN=nonsense'),
        ]
        for env in bad:
            (root / '.env.sentry').write_text(env)
            code, text = run(tool(root, 'define', '--out', str(out)), work)
            assert code != 0 and not out.exists(), env
            no_secret(text, (DSN, TEST_DSN))
        (root / '.env.sentry').write_text(ENV_OK)
        (root / 'pubspec.yaml').write_text('name: x\nversion: latest\n')
        assert run(tool(root, 'define', '--out', str(out)), work)[0] != 0


def build_web(work, release, maps=True, bundle_release=None, bundle_dsn=DSN):
    web = work / 'out' / 'web'
    web.mkdir(parents=True)
    (web / 'main.dart.js').write_text('var r="%s",d="%s";\n//# sourceMappingURL=main.dart.js.map\n' % (bundle_release or release, bundle_dsn))
    (web / 'flutter_bootstrap.js').write_text('boot')
    (web / 'main.dart.mjs').write_text('mjs')
    (web / 'main.dart.wasm').write_bytes(b'\0asm')
    if maps:
        (web / 'main.dart.js.map').write_text('{"version":3,"mappings":""}')
        (web / 'main.dart.wasm.map').write_text('{"version":3,"mappings":""}')
    return web


def prepared(work):
    root = make_root(work)
    fake_bin(work)
    defines = work / 'd.json'
    assert run(tool(root, 'define', '--out', str(defines)), work)[0] == 0
    return root, defines, json.loads(defines.read_text())['SENTRY_RELEASE']


def test_upload():
    with workdir() as w:
        work = Path(w)
        root, defines, rel = prepared(work)
        web = build_web(work, rel)
        wasm_before = (web / 'main.dart.wasm.map').read_bytes()
        code, text = run(tool(root, 'upload', '--web-dir', str(web), '--define-file', str(defines)), work)
        assert code == 0 and 'JS/map 쌍 1개' in text, text
        no_secret(text)
        [c] = calls(work)
        a = c['args']
        assert a[:2] == ['sourcemap', 'upload'] and a[a.index('--release') + 1] == rel, a
        assert a[a.index('--url-prefix') + 1] == '~/match/' and '--ext' in a, a
        # 인증 토큰과 DSN은 CLI 환경에서 제거, org/project만 환경변수로
        assert c['token'] is None and c['dsn'] is None, c
        assert (c['org'], c['project']) == (ORG, PROJECT)
        assert not any(ORG in x or PROJECT in x or TOKEN in x for x in a)
        # JS 쌍만 올림: wasm map, mjs, 다른 JS는 대상이 아님. 저장소 .env 접근을 막으려 cwd도 분리
        assert c['files'] == ['main.dart.js', 'main.dart.js.map'], c['files']
        assert str(root) not in c['cwd'] and str(web.parent) not in c['cwd']
        # 주입된 JS가 web 원본에 돌아와 있음. 다른 파일은 그대로
        assert 'debugId=' in (web / 'main.dart.js').read_text()
        assert (web / 'flutter_bootstrap.js').read_text() == 'boot'
        assert (web / 'main.dart.wasm.map').read_bytes() == wasm_before
        assert not [p for p in web.parent.iterdir() if p.name.startswith('sentry-stage')]


def test_upload_failures_block():
    def case(prep, mode='ok'):
        with workdir() as w:
            work = Path(w)
            root, defines, rel = prepared(work)
            web = prep(work, root, defines, rel)
            code, text = run(tool(root, 'upload', '--web-dir', str(web), '--define-file', str(defines)), work, mode)
            assert code != 0, text
            no_secret(text)
            return calls(work), (web / 'main.dart.js').read_text()

    # CLI 실패는 전파. 실패 뒤 web에 주입 흔적 없음
    c, js = case(lambda w, r, d, rel: build_web(w, rel), mode='fail')
    assert len(c) == 1 and 'debugId' not in js
    # CLI가 debug ID를 주입하지 않으면 실패
    case(lambda w, r, d, rel: build_web(w, rel), mode='noinject')
    # 번들 release 불일치, map 없음, 소스가 define 뒤에 변경, 잘못된 define 파일: CLI 호출 없음
    c, _ = case(lambda w, r, d, rel: build_web(w, rel, bundle_release='stone-match@0.0.0-old'))
    assert c == []
    c, _ = case(lambda w, r, d, rel: build_web(w, rel, maps=False))
    assert c == []

    def changed(w, r, d, rel):
        (r / 'lib' / 'main.dart').write_text('void main() { /* after define */ }\n')
        return build_web(w, rel)
    assert case(changed)[0] == []

    def leaked_key(w, r, d, rel):
        d.write_text(json.dumps({**json.loads(d.read_text()), 'SENTRY_ORG': ORG}))
        return build_web(w, rel)
    assert case(leaked_key)[0] == []

    def other_dsn(w, r, d, rel):
        d.write_text(json.dumps({**json.loads(d.read_text()), 'SENTRY_DSN': TEST_DSN}))
        return build_web(w, rel)
    assert case(other_dsn)[0] == []

    # 설정이 비활성이면 업로드를 요청해도 실패
    with workdir() as w:
        work = Path(w)
        root, defines, rel = prepared(work)
        (root / '.env.sentry').write_text('SENTRY_DSN=\n')
        web = build_web(work, rel)
        assert run(tool(root, 'upload', '--web-dir', str(web), '--define-file', str(defines)), work)[0] != 0
        assert calls(work) == []
    # sentry 실행 파일이 없으면 실패
    with workdir() as w:
        work = Path(w)
        root, defines, rel = prepared(work)
        (work / 'bin' / 'sentry').unlink()
        web = build_web(work, rel)
        code, text = run(['/usr/bin/env', 'PATH=' + str(work / 'bin') + ':/usr/bin:/bin'] + tool(root, 'upload', '--web-dir', str(web), '--define-file', str(defines)), work)
        assert code != 0, text


def test_strip_and_check_zip():
    with workdir() as w:
        work = Path(w)
        root, defines, rel = prepared(work)
        pkg = work / 'match'
        (pkg / 'sub').mkdir(parents=True)
        for n in ('main.dart.js', 'a.js.map', 'main.dart.wasm.map', 'sub/x.map', 'index.html'):
            (pkg / n).write_text('x')
        (pkg / 'main.dart.js').write_text('r="%s",d="%s"\n//# debugId=7b4e8566-5998-4f68-9e22-8ab712e5b66c\n' % (rel, DSN))
        code, text = run(tool(root, 'strip-maps', '--dir', str(pkg)), work)
        assert code == 0 and '3개' in text and not list(pkg.rglob('*.map')), text
        assert (pkg / 'main.dart.js').exists() and (pkg / 'index.html').exists()

        def make_zip(name, extra=None, main=None):
            z = work / name
            with zipfile.ZipFile(z, 'w') as f:
                f.writestr('match/main.dart.js', main if main is not None else (pkg / 'main.dart.js').read_text())
                f.writestr('match/index.html', 'x')
                for n in extra or ():
                    f.writestr(n, 'x')
            return z
        ok = make_zip('ok.zip')
        assert run(tool(root, 'check-zip', '--zip', str(ok), '--define-file', str(defines)), work)[0] == 0
        assert run(tool(root, 'check-zip', '--zip', str(ok)), work)[0] == 0
        for extra in (['match/main.dart.wasm.map'], ['match/deep/x.js.map'], ['match/.env.sentry'], ['match/.env']):
            z = make_zip('bad.zip', extra)
            assert run(tool(root, 'check-zip', '--zip', str(z)), work)[0] != 0, extra
        # release 불일치나 debug ID 없음
        assert run(tool(root, 'check-zip', '--zip', str(make_zip('r.zip', main='r="other",d="x"\n//# debugId=7b4e8566-5998-4f68-9e22-8ab712e5b66c\n')),
                        '--define-file', str(defines)), work)[0] != 0
        assert run(tool(root, 'check-zip', '--zip', str(make_zip('n.zip', main='r="%s"\n' % rel)),
                        '--define-file', str(defines)), work)[0] != 0


def deploy(work, root, mode='ok', *flags):
    out = work / 'out'
    cmd = ['bash', str(root / 'tools' / 'deploy_match_web.sh'), '--deploy-url', 'https://nas.example/deploy.php',
           '--token', 'deploy-token-value', '--env-file', str(work / 'nonexistent.env'), '--output-dir', str(out), *flags]
    return run(cmd, work, mode, cwd=root), out


def zip_names(out):
    with zipfile.ZipFile(out / 'match.zip') as z:
        return z.namelist()


def test_deploy_script():
    # 1) 활성: source-maps 빌드, 업로드 뒤 패키징/배포, map은 ZIP과 match에서 제외, web 원본에는 보존
    with workdir() as w:
        work = Path(w)
        root = make_root(work)
        fake_bin(work)
        (code, text), out = deploy(work, root)
        assert code == 0, text
        no_secret(text, (DSN, 'deploy-token-value'))
        flutter = json.loads((work / 'flutter.json').read_text())
        assert '--source-maps' in flutter and '--wasm' in flutter
        defines = out / 'sentry-defines.json'
        assert f'--dart-define-from-file={defines}' in flutter
        rel = json.loads(defines.read_text())['SENTRY_RELEASE']
        assert len(calls(work)) == 1 and (work / 'sentry.log.curl').exists()
        names = zip_names(out)
        assert not [n for n in names if n.endswith('.map')] and 'match/main.dart.js' in names
        assert not [n for n in names if 'sentry-defines' in n]
        assert not list((out / 'match').rglob('*.map'))
        assert (out / 'web' / 'main.dart.wasm.map').exists() and (out / 'web' / 'main.dart.js.map').exists()
        with zipfile.ZipFile(out / 'match.zip') as z:
            data = z.read('match/main.dart.js').decode()
        assert rel in data and 'debugId=' in data

    # 2) 업로드 실패: 패키징과 배포 없음
    with workdir() as w:
        work = Path(w)
        root = make_root(work)
        fake_bin(work)
        (code, text), out = deploy(work, root, 'fail')
        assert code != 0, text
        no_secret(text, (DSN, 'deploy-token-value'))
        assert not (out / 'match').exists() and not (out / 'match.zip').exists()
        assert not (work / 'sentry.log.curl').exists()

    # 3) 잘못된 설정: 빌드 전에 중단, flutter/sentry/배포 없음
    with workdir() as w:
        work = Path(w)
        root = make_root(work, env_text=f'SENTRY_DSN={DSN}\n')
        fake_bin(work)
        (code, text), out = deploy(work, root)
        assert code != 0, text
        no_secret(text, (DSN, 'deploy-token-value'))
        assert not (work / 'flutter.json').exists() and calls(work) == []
        assert not (work / 'sentry.log.curl').exists()

    # 4) 비활성(파일 없음, 빈 템플릿, --no-sentry): 종전 빌드. map 없음, sentry 호출 없음
    for env_text, flags in ((None, ()), ('SENTRY_DSN=\nSENTRY_ORG=\nSENTRY_PROJECT=\n', ()), (ENV_OK, ('--no-sentry',))):
        with workdir() as w:
            work = Path(w)
            root = make_root(work, env_text=env_text)
            fake_bin(work)
            (code, text), out = deploy(work, root, 'ok', *flags)
            assert code == 0, text
            flutter = json.loads((work / 'flutter.json').read_text())
            assert '--source-maps' not in flutter
            assert not [a for a in flutter if 'sentry-defines' in a], flutter
            assert calls(work) == [] and (work / 'sentry.log.curl').exists()
            assert not [n for n in zip_names(out) if n.endswith('.map')]


QA_ENV = ENV_OK.replace('SENTRY_TEST_DSN=', f'SENTRY_TEST_DSN={TEST_DSN}') + 'SENTRY_TEST_PROJECT=qa-project-z\n'


def test_qa_project_upload():
    with workdir() as w:
        work = Path(w)
        root, _, _ = prepared(work)
        (root / '.env.sentry').write_text(QA_ENV)
        defines = work / 'dq.json'
        code, text = run(tool(root, 'define', '--out', str(defines)), work)
        assert code == 0, text
        # QA project 값은 로컬 관리 필드라 define과 출력에 없다. QA DSN은 기존처럼 define에 있다.
        assert 'qa-project-z' not in defines.read_text() + text
        d = json.loads(defines.read_text())
        assert set(d) == {'SENTRY_DSN', 'SENTRY_TEST_DSN', 'SENTRY_RELEASE'}
        rel = d['SENTRY_RELEASE']
        web = build_web(work, rel)
        code, text = run(tool(root, 'upload', '--web-dir', str(web), '--define-file', str(defines)), work)
        assert code == 0 and '프로젝트 2곳' in text, text
        no_secret(text, ('qa-project-z',))
        c = calls(work)
        assert [x['project'] for x in c] == [PROJECT, 'qa-project-z'], c
        for x in c:
            assert x['org'] == ORG and x['token'] is None and x['dsn'] is None and x['test_project_env'] is None
            assert x['args'][x['args'].index('--release') + 1] == rel
            assert not any('qa-project-z' in a or PROJECT in a for a in x['args'])
        # 두 번째 호출 시점에 JS는 이미 주입된 상태 그대로(재주입 없음), 최종 web도 debug ID 한 번
        assert (web / 'main.dart.js').read_text().count('debugId=') == 1
        assert 'debugId=' in (web / 'main.dart.js').read_text()


def test_qa_project_from_process_env():
    with workdir() as w:
        work = Path(w)
        root, _, _ = prepared(work)
        (root / '.env.sentry').write_text(ENV_OK.replace('SENTRY_TEST_DSN=', f'SENTRY_TEST_DSN={TEST_DSN}'))
        defines = work / 'dq.json'
        env = {'SENTRY_TEST_PROJECT': 'qa-from-env'}
        assert run(tool(root, 'define', '--out', str(defines)), work, extra=env)[0] == 0
        assert 'qa-from-env' not in defines.read_text()
        web = build_web(work, json.loads(defines.read_text())['SENTRY_RELEASE'])
        code, text = run(tool(root, 'upload', '--web-dir', str(web), '--define-file', str(defines)), work, extra=env)
        assert code == 0, text
        assert [x['project'] for x in calls(work)] == [PROJECT, 'qa-from-env']
        assert all(x['test_project_env'] is None for x in calls(work))


def test_qa_project_failclosed():
    with workdir() as w:
        work = Path(w)
        root, _, rel = prepared(work)
        out = work / 'dq.json'
        bad = [
            ENV_OK + 'SENTRY_TEST_PROJECT=qa-project-z\n',                  # QA DSN 없이 QA project
            QA_ENV.replace('qa-project-z', PROJECT),                           # 운영과 같은 project
            QA_ENV.replace('qa-project-z', 'bad slug/'),
        ]
        for env in bad:
            (root / '.env.sentry').write_text(env)
            code, text = run(tool(root, 'define', '--out', str(out)), work)
            assert code != 0 and not out.exists(), env
            no_secret(text, ('qa-project-z',))
        # QA project 없이 QA DSN만 있으면 운영 project만 업로드(기존 동작)
        (root / '.env.sentry').write_text(ENV_OK.replace('SENTRY_TEST_DSN=', f'SENTRY_TEST_DSN={TEST_DSN}'))
        assert run(tool(root, 'define', '--out', str(out)), work)[0] == 0
        web = build_web(work, json.loads(out.read_text())['SENTRY_RELEASE'])
        assert run(tool(root, 'upload', '--web-dir', str(web), '--define-file', str(out)), work)[0] == 0
        assert [x['project'] for x in calls(work)] == [PROJECT]


def test_qa_upload_failures_block():
    def case(env_mode):
        with workdir() as w:
            work = Path(w)
            root, _, _ = prepared(work)
            (root / '.env.sentry').write_text(QA_ENV)
            defines = work / 'dq.json'
            run(tool(root, 'define', '--out', str(defines)), work)
            web = build_web(work, json.loads(defines.read_text())['SENTRY_RELEASE'])
            before = (web / 'main.dart.js').read_bytes()
            code, text = run(tool(root, 'upload', '--web-dir', str(web), '--define-file', str(defines)),
                             work, extra=env_mode)
            assert code != 0, text
            no_secret(text, ('qa-project-z',))
            assert (web / 'main.dart.js').read_bytes() == before  # 실패하면 web 원본을 바꾸지 않는다
            return [x['project'] for x in calls(work)]
    # QA 업로드 실패, QA 업로드가 주입 결과를 바꿈(불변 위반): 모두 실패
    assert case({'FAKE_MODE_QA_PROJECT_Z': 'fail'}) == [PROJECT, 'qa-project-z']
    assert case({'FAKE_MODE_QA_PROJECT_Z': 'mutate'}) == [PROJECT, 'qa-project-z']
    # 운영 업로드가 실패하면 QA 업로드는 시작하지 않는다
    assert case({'FAKE_MODE_' + PROJECT.replace('-', '_').upper(): 'fail'}) == [PROJECT]


def test_bundle_dsn_required():
    with workdir() as w:
        work = Path(w)
        root, defines, rel = prepared(work)
        web = build_web(work, rel, bundle_dsn='https://other@o1.ingest.example.io/1')
        code, text = run(tool(root, 'upload', '--web-dir', str(web), '--define-file', str(defines)), work)
        assert code != 0 and calls(work) == [], text
        no_secret(text, (DSN,))
        pkg = work / 'pkg'
        pkg.mkdir()
        z = work / 'nodsn.zip'
        with zipfile.ZipFile(z, 'w') as f:
            f.writestr('match/main.dart.js', 'r="%s"\n//# debugId=7b4e8566-5998-4f68-9e22-8ab712e5b66c\n' % rel)
        code, text = run(tool(root, 'check-zip', '--zip', str(z), '--define-file', str(defines)), work)
        assert code != 0, text


def test_patch_keeps_length():
    """Intl 패치가 원본 문자 길이를 유지해 같은 줄 뒤쪽의 source map column이 밀리지 않는지 확인한다."""
    a = 'typeof Intl.v8BreakIterator<"u"&&typeof Intl.Segmenter<"u"'
    b = 's.Intl.v8BreakIterator!=null&&s.Intl.Segmenter!=null'
    tail = 'MARK_AFTER'
    with workdir() as w:
        web = Path(w) / 'web'
        web.mkdir()
        files = {
            'main.dart.js': f'x=1;if({a}){{y({b})}}{tail}\nnext_line_{tail}\n',
            'flutter.js': f'if({a}){tail}',
            'flutter_bootstrap.js': f'({b}){tail}',
        }
        for n, t in files.items():
            (web / n).write_text(t)
        r = subprocess.run(['dart', 'run', 'tools/patch_flutter_web_deprecations.dart', str(web)],
                           cwd=ROOT, capture_output=True, text=True)
        assert r.returncode == 0, r.stderr
        for n, before in files.items():
            after = (web / n).read_text()
            assert len(after) == len(before), n
            assert 'v8BreakIterator' not in after, n
            # 줄 수와 뒤쪽 표식의 line/column이 원본과 같다
            assert after.splitlines()[0].index(tail) == before.splitlines()[0].index(tail), n
            assert after.count('\n') == before.count('\n'), n
            assert after.isascii()
        main = (web / 'main.dart.js').read_text()
        assert 'typeof Intl.Segmenter<"u"' in main and 's.Intl.Segmenter!=null' in main
        # 다시 실행해도 그대로(이미 패치된 파일은 바뀌지 않는다)
        r2 = subprocess.run(['dart', 'run', 'tools/patch_flutter_web_deprecations.dart', str(web)],
                            cwd=ROOT, capture_output=True, text=True)
        assert r2.returncode == 0 and (web / 'main.dart.js').read_text() == main
        # 치환 대상이 없는 JS는 바이트 그대로
        (web / 'main.dart.js').write_text('plain code;')
        for n in ('flutter.js', 'flutter_bootstrap.js'):
            (web / n).write_text('plain')
        subprocess.run(['dart', 'run', 'tools/patch_flutter_web_deprecations.dart', str(web)],
                       cwd=ROOT, capture_output=True, text=True, check=True)
        assert (web / 'main.dart.js').read_text() == 'plain code;'


def test_source_content_private_upload():
    import importlib.util
    from unittest.mock import patch
    spec = importlib.util.spec_from_file_location('sentry_web_build', TOOL)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    with tempfile.TemporaryDirectory(dir=TMP) as td:
        root = Path(td)
        web = root / 'web'
        web.mkdir()
        (root / 'app.dart').write_text('void main() {}')
        sdk = root / 'flutter/bin/cache/dart-sdk/lib/core.dart'
        sdk.parent.mkdir(parents=True)
        sdk.write_text('// SDK source')
        engine = root / 'flutter/bin/cache/flutter_web_sdk/lib/ui.dart'
        engine.parent.mkdir(parents=True)
        engine.write_text('// engine source')
        (web / '.env').write_text('SECRET_MUST_NOT_UPLOAD')
        original, staged = web / 'main.dart.js.map', root / 'stage.map'
        original.write_text(json.dumps({'sources': ['../app.dart',
            'org-dartlang-sdk:///dart-sdk/lib/core.dart',
            'org-dartlang-sdk:///lib/ui.dart', '.env', 'https://remote/x.dart']}))
        with patch.object(helper.shutil, 'which', return_value=str(root / 'flutter/bin/flutter')):
            helper.embed_source_content(original, staged)
        contents = json.loads(staged.read_text())['sourcesContent']
        assert contents == ['void main() {}', '// SDK source', '// engine source', None, None]
        assert 'SECRET_MUST_NOT_UPLOAD' not in staged.read_text()
        assert 'sourcesContent' not in json.loads(original.read_text())


if __name__ == '__main__':
    for name, fn in sorted(globals().items()):
        if name.startswith('test_'):
            fn()
            print(f'ok {name}')
    print('all ok')
