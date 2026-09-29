#!/usr/bin/env python3
"""NAS 웹 빌드용 Sentry 보조 도구(PLAN-012). 값은 출력하지 않고 개수와 성공 여부만 알린다.

  define      .env.sentry에서 앱에 넣을 공개 define JSON을 만든다(SENTRY_DSN, SENTRY_TEST_DSN, SENTRY_RELEASE).
              설정이 비어 있으면 파일을 만들지 않고 disabled로 끝낸다. 일부만 있거나 값이 틀리면 실패한다.
  upload      build/web의 JS와 JS map 쌍만 sentry CLI(기존 로그인)로 올리고 debug ID가 주입된 JS를 돌려 놓는다.
              SENTRY_TEST_PROJECT가 있으면 같은 주입 결과를 QA 프로젝트에도 올린다(debug ID 불변 확인).
  strip-maps  패키지 폴더에서 *.map을 모두 지운다.
  check-zip   ZIP에 *.map, .env 파일이 없는지, (define 파일을 주면) 번들 DSN, release, debug ID가 있는지 확인한다.

.env.sentry의 SENTRY_AUTH_TOKEN은 읽지 않고 sentry CLI 환경에서도 제거한다. org/project는 CLI 환경변수로만 전달한다.
SENTRY_TEST_PROJECT(선택)는 로컬 관리 값이다. .env.sentry 또는 프로세스 환경변수로 주며 앱 define에는 넣지 않는다.
sentry sourcemap upload에는 --project 옵션이 없어 프로젝트마다 SENTRY_PROJECT 환경변수를 바꿔 호출한다.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
DEFINE_KEYS = ('SENTRY_DSN', 'SENTRY_TEST_DSN', 'SENTRY_RELEASE')
URL_PREFIX = '~/match/'
PUBLIC_ENV_KEYS = ('SENTRY_DSN', 'SENTRY_TEST_DSN', 'SENTRY_ORG', 'SENTRY_PROJECT', 'SENTRY_TEST_PROJECT')
SLUG = re.compile(r'^[A-Za-z0-9][A-Za-z0-9_-]*$')
DEBUG_ID = re.compile(rb'//# debugId=[0-9a-fA-F-]{36}')
STRIP_ENV = ('SENTRY_AUTH_TOKEN', 'SENTRY_API_KEY', 'SENTRY_DSN')


def fail(reason):
    sys.exit(f'sentry_web_build: {reason}')


def load_env(path):
    """공개 키 4개만 읽는다. 다른 키(SENTRY_AUTH_TOKEN 포함)의 값은 보관하지 않는다."""
    vals = {}
    for line in Path(path).read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, value = line.split('=', 1)
        key = key.strip()
        if key in PUBLIC_ENV_KEYS:
            vals[key] = value.strip().strip('"\'')
    return vals


def check_dsn(name, dsn):
    try:
        p = urlsplit(dsn)
        ok = (p.scheme == 'https' and p.hostname and p.username and not p.password
              and not p.query and not p.fragment
              and re.fullmatch(r'/(?:[^/\s]+/)*\d+', p.path or '') is not None
              and not any(c.isspace() for c in dsn))
    except ValueError:
        ok = False
    if not ok:
        fail(f'{name} 형식이 올바르지 않습니다(https://<공개키>@<호스트>/<프로젝트번호>).')


def load_config(env_file):
    """None이면 비활성. 일부만 채웠거나 형식이 틀리면 실패한다(오류 문구에 값 없음)."""
    if not Path(env_file).is_file():
        return None
    vals = {k: v for k, v in load_env(env_file).items() if v}
    if not vals.get('SENTRY_TEST_PROJECT') and os.environ.get('SENTRY_TEST_PROJECT'):
        vals['SENTRY_TEST_PROJECT'] = os.environ['SENTRY_TEST_PROJECT'].strip()
    if not vals:
        return None
    missing = [k for k in ('SENTRY_DSN', 'SENTRY_ORG', 'SENTRY_PROJECT') if k not in vals]
    if missing:
        fail('Sentry 설정이 일부만 있습니다. 없는 키: ' + ', '.join(missing))
    check_dsn('SENTRY_DSN', vals['SENTRY_DSN'])
    if 'SENTRY_TEST_DSN' in vals:
        check_dsn('SENTRY_TEST_DSN', vals['SENTRY_TEST_DSN'])
        if vals['SENTRY_TEST_DSN'] == vals['SENTRY_DSN']:
            fail('SENTRY_TEST_DSN은 SENTRY_DSN과 달라야 합니다.')
    for key in ('SENTRY_ORG', 'SENTRY_PROJECT', 'SENTRY_TEST_PROJECT'):
        if key in vals and not SLUG.fullmatch(vals[key]):
            fail(f'{key} 형식이 올바르지 않습니다.')
    if 'SENTRY_TEST_PROJECT' in vals:
        if 'SENTRY_TEST_DSN' not in vals:
            fail('SENTRY_TEST_PROJECT에는 SENTRY_TEST_DSN이 필요합니다.')
        if vals['SENTRY_TEST_PROJECT'] == vals['SENTRY_PROJECT']:
            fail('SENTRY_TEST_PROJECT는 SENTRY_PROJECT와 달라야 합니다.')
    return vals


def source_hash(root):
    """앱 번들에 영향을 주는 소스(lib, web, pubspec)의 내용 해시. dirty 작업트리도 그대로 반영된다."""
    files = [root / 'pubspec.yaml', root / 'pubspec.lock']
    for sub in ('lib', 'web'):
        files += [p for p in (root / sub).rglob('*') if p.is_file()]
    h = hashlib.sha256()
    for p in sorted(f for f in files if f.is_file() and f.name != '.DS_Store'):
        data = p.read_bytes()
        h.update(f'{p.relative_to(root).as_posix()}\0{len(data)}\0'.encode() + data)
    return h.hexdigest()[:12]


def make_release(root):
    m = re.search(r'^version:\s*(\d+\.\d+\.\d+(?:\+\d+)?)\s*$',
                  (root / 'pubspec.yaml').read_text(encoding='utf-8'), re.M)
    if not m:
        fail('pubspec.yaml version을 읽지 못했습니다.')
    return f'stone-match@{m.group(1)}-{source_hash(root)}'


def cmd_define(a):
    cfg = load_config(a.env_file)
    if cfg is None:
        print('sentry: disabled')
        return
    defines = {'SENTRY_DSN': cfg['SENTRY_DSN']}
    if 'SENTRY_TEST_DSN' in cfg:
        defines['SENTRY_TEST_DSN'] = cfg['SENTRY_TEST_DSN']
    defines['SENTRY_RELEASE'] = make_release(a.root)
    Path(a.out).write_text(json.dumps(defines), encoding='utf-8')
    print(f'sentry: enabled (defines {len(defines)}개, release {defines["SENTRY_RELEASE"]})')


def js_pairs(web):
    return sorted(p for p in web.rglob('*.js') if Path(str(p) + '.map').is_file())


def embed_source_content(original_map, staged_map):
    """Flutter map에 Dart 원문을 넣어 비공개 업로드만으로 소스 문맥도 복원한다."""
    data = json.loads(original_map.read_text(encoding='utf-8'))
    sources = data.get('sources', [])
    contents = data.get('sourcesContent') or [None] * len(sources)
    if len(contents) != len(sources):
        fail('source map sourcesContent 길이가 sources와 다릅니다.')
    flutter = shutil.which('flutter')
    cache = Path(flutter).resolve().parents[1] / 'bin/cache' if flutter else None
    for index, source in enumerate(sources):
        if contents[index] is not None or not source.endswith('.dart'):
            continue
        if source.startswith('org-dartlang-sdk:///'):
            if cache is None:
                continue
            relative = source.removeprefix('org-dartlang-sdk:///')
            candidate = (cache / relative if relative.startswith('dart-sdk/')
                         else cache / 'flutter_web_sdk' / relative)
        elif '://' not in source:
            candidate = original_map.parent / data.get('sourceRoot', '') / source
        else:
            continue
        if candidate.is_file():
            contents[index] = candidate.read_text(encoding='utf-8')
    data['sourcesContent'] = contents
    staged_map.write_text(json.dumps(data, separators=(',', ':')), encoding='utf-8')


def stage_state(stage, rel):
    """JS 바이트 해시와 map의 debug ID. 업로드 사이에 바뀌면 프로젝트 간 심볼이 어긋난다."""
    js = stage / rel
    m = Path(str(js) + '.map')
    try:
        d = json.loads(m.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        fail('map을 읽지 못했습니다.')
    return (hashlib.sha256(js.read_bytes()).hexdigest(), d.get('debug_id') or d.get('debugId'))


def check_bundle(data, defines, what):
    """번들에 앱 define(운영 DSN, release)이 들어 있는지 확인한다. 값은 출력하지 않는다."""
    if defines['SENTRY_DSN'].encode() not in data:
        fail(f'{what}에 SENTRY_DSN이 없습니다. define 없이 빌드됐거나 앱이 읽지 않습니다.')
    if defines['SENTRY_RELEASE'].encode() not in data:
        fail(f'{what}에 release가 없습니다. 다른 define으로 빌드된 산출물입니다.')


def cmd_upload(a):
    cfg = load_config(a.env_file)
    if cfg is None:
        fail('Sentry 설정이 비활성인데 업로드가 요청됐습니다.')
    try:
        defines = json.loads(Path(a.define_file).read_text(encoding='utf-8'))
    except (OSError, ValueError):
        fail('define 파일을 읽지 못했습니다.')
    if (not isinstance(defines, dict) or not set(defines) <= set(DEFINE_KEYS)
            or not {'SENTRY_DSN', 'SENTRY_RELEASE'} <= set(defines)):
        fail('define 파일 키가 허용 목록과 다릅니다.')
    if defines['SENTRY_DSN'] != cfg['SENTRY_DSN']:
        fail('define 파일의 DSN이 .env.sentry와 다릅니다.')
    release = defines['SENTRY_RELEASE']
    if release != make_release(a.root):
        fail('define 생성 뒤 소스가 바뀌어 release가 일치하지 않습니다.')
    web = Path(a.web_dir).resolve()
    main_js = web / 'main.dart.js'
    if not main_js.is_file() or not Path(str(main_js) + '.map').is_file():
        fail('main.dart.js 또는 main.dart.js.map이 없습니다(--source-maps 빌드 필요).')
    check_bundle(main_js.read_bytes(), defines, '빌드 산출물')
    pairs = js_pairs(web)
    projects = [cfg['SENTRY_PROJECT']] + ([cfg['SENTRY_TEST_PROJECT']] if 'SENTRY_TEST_PROJECT' in cfg else [])
    with tempfile.TemporaryDirectory(dir=web.parent, prefix='sentry-stage-') as stage_dir, \
            tempfile.TemporaryDirectory(prefix='sentry-cwd-') as cwd:
        stage = Path(stage_dir)
        for p in pairs:
            for src in (p, Path(str(p) + '.map')):
                dst = stage / src.relative_to(web)
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
        for p in pairs:
            embed_source_content(Path(str(p) + '.map'), stage / (str(p.relative_to(web)) + '.map'))
        env = {k: v for k, v in os.environ.items() if k not in STRIP_ENV + ('SENTRY_TEST_PROJECT',)}
        env['SENTRY_ORG'] = cfg['SENTRY_ORG']
        cmd = ['sentry', 'sourcemap', 'upload', str(stage), '--release', release,
               '--url-prefix', URL_PREFIX, '--ext', '.js']
        injected = None
        for project in projects:
            env['SENTRY_PROJECT'] = project
            try:
                r = subprocess.run(cmd, env=env, cwd=cwd, capture_output=True)
            except OSError:
                fail('sentry CLI를 실행하지 못했습니다.')
            if r.returncode != 0:
                fail(f'sentry sourcemap upload 실패(종료 코드 {r.returncode}). 배포를 진행하지 않습니다.')
            state = {p.relative_to(web): stage_state(stage, p.relative_to(web)) for p in pairs}
            if injected is None:
                injected = state
            elif state != injected:
                fail('QA 업로드 뒤 JS 또는 debug ID가 바뀌었습니다. 프로젝트마다 같은 파일이어야 합니다.')
        for p in pairs:
            rel = p.relative_to(web)
            if not DEBUG_ID.search((stage / rel).read_bytes()):
                fail('업로드 뒤 JS에 debug ID가 주입되지 않았습니다.')
            if rel.name == 'main.dart.js':
                check_bundle((stage / rel).read_bytes(), defines, '주입된 JS')
        for p in pairs:
            rel = p.relative_to(web)
            for src in (rel, Path(str(rel) + '.map')):
                shutil.copy2(stage / src, web / src)
    print(f'sentry upload: JS/map 쌍 {len(pairs)}개, 프로젝트 {len(projects)}곳 업로드 완료, '
          'debug ID 주입과 프로젝트 간 불변, DSN/release 번들 일치 확인')


def cmd_strip_maps(a):
    maps = list(Path(a.dir).rglob('*.map'))
    for p in maps:
        p.unlink()
    if list(Path(a.dir).rglob('*.map')):
        fail('*.map 삭제 후에도 남아 있습니다.')
    print(f'source map {len(maps)}개 제외')


def cmd_check_zip(a):
    with zipfile.ZipFile(a.zip) as z:
        names = z.namelist()
        bad = [n for n in names if n.endswith('.map') or Path(n).name.startswith('.env')]
        if bad:
            fail(f'ZIP에 제외 대상 파일이 {len(bad)}개 있습니다(*.map, .env*).')
        if a.define_file:
            defines = json.loads(Path(a.define_file).read_text(encoding='utf-8'))
            mains = [n for n in names if n.endswith('/main.dart.js')]
            if len(mains) != 1:
                fail('ZIP의 main.dart.js를 하나로 찾지 못했습니다.')
            data = z.read(mains[0])
            if not DEBUG_ID.search(data):
                fail('ZIP의 main.dart.js에 debug ID가 없습니다.')
            check_bundle(data, defines, 'ZIP의 main.dart.js')
    print(f'ZIP 검사 통과: 항목 {len(names)}개, map/env 0개' + (', DSN, release, debug ID 일치' if a.define_file else ''))


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--root', type=Path, default=ROOT)
    sub = ap.add_subparsers(dest='cmd', required=True)
    d = sub.add_parser('define')
    d.add_argument('--out', required=True)
    u = sub.add_parser('upload')
    u.add_argument('--web-dir', required=True)
    u.add_argument('--define-file', required=True)
    for p in (d, u):
        p.add_argument('--env-file', default=None)
    s = sub.add_parser('strip-maps')
    s.add_argument('--dir', required=True)
    z = sub.add_parser('check-zip')
    z.add_argument('--zip', required=True)
    z.add_argument('--define-file', default=None)
    a = ap.parse_args(argv)
    if getattr(a, 'env_file', 1) is None:
        a.env_file = a.root / '.env.sentry'
    {'define': cmd_define, 'upload': cmd_upload, 'strip-maps': cmd_strip_maps,
     'check-zip': cmd_check_zip}[a.cmd](a)


if __name__ == '__main__':
    main(sys.argv[1:])
