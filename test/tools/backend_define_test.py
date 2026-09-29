"""tools/backend_define.sh 회귀. 실제 config는 읽지 않고 tmp/ 아래 합성 fixture만 쓴다.

실행: python3 test/tools/backend_define_test.py
"""
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'tools' / 'backend_define.sh'
TMP = ROOT / 'tmp' / 'pocketbase-followup-20260929'
OK = '--dart-define-from-file=config/pocketbase.json\n'


def run(files, *args):
    TMP.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=TMP) as cwd:
        (Path(cwd) / 'config').mkdir()
        for name, body in files.items():
            text = body if isinstance(body, str) else json.dumps(body)
            (Path(cwd) / 'config' / name).write_text(text, encoding='utf-8')
        r = subprocess.run(['bash', str(SCRIPT), *args], cwd=cwd,
                           capture_output=True, text=True)
        return r.returncode, r.stdout, r.stderr


def pb(url):
    return {'pocketbase.json': {'POCKETBASE_URL': url}}


def main():
    for mode in ([], ['--required']):
        assert run(pb('https://pb.example'), *mode) == (0, OK, ''), mode
        assert run(pb('https://pb.example/base/'), *mode)[:2] == (0, OK)
    # 미설정: dev 빈 출력, prod 거절. supabase.json만 있어도 사용하지 않는다.
    assert run({}) == (0, '', '')
    assert run({}, '--required')[0] == 1
    old = {'supabase.json': {'SUPABASE_URL': 'https://x.supabase.co'}}
    assert run(old) == (0, '', '')
    code, out, _ = run(old, '--required')
    assert code == 1 and out == ''
    secret = 'admin-secret-value'
    bad = [
        {'pocketbase.json': '{not json'},
        {'pocketbase.json': '["https://pb.example"]'},
        {'pocketbase.json': {}},
        {'pocketbase.json': {'POCKETBASE_URL': 'https://pb.example',
                             'POCKETBASE_ADMIN_PASSWORD': secret}},
        pb(''), pb(None), pb(1), pb(' https://pb.example'),
        pb('http://pb.example'), pb('https://'), pb('pb.example'),
        pb(f'https://admin:{secret}@pb.example'),
        pb('https://user@pb.example'),
        pb('https://pb.example?token=x'), pb('https://pb.example?'),
        pb('https://pb.example#x'), pb('https://[bad/'),
    ]
    for files in bad:
        for mode in ([], ['--required']):
            code, out, err = run(files, *mode)
            assert code != 0 and out == '', (files, mode, code, out)
            assert secret not in err and 'x.supabase' not in err, err
    print(f'backend_define: {len(bad) * 2 + 8} cases passed')


if __name__ == '__main__':
    main()
