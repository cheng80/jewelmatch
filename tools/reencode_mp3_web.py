#!/usr/bin/env python3
"""
폴더 안의 MP3를 웹·audioplayers 호환에 맞춰 일괄 재인코딩한다.
실제 인코딩은 ffmpeg(libmp3lame)를 사용한다. (Python만으로 MP3 인코딩하려면 lame 등 별도 바인딩이 필요해 비추천)

사전 요건: PATH에 ffmpeg 가 있어야 한다.

예시:
  python3 tools/reencode_mp3_web.py assets/audio/sfx
  python3 tools/reencode_mp3_web.py assets/audio --recursive
  python3 tools/reencode_mp3_web.py assets/audio/sfx --dry-run
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def find_mp3(root: Path, recursive: bool) -> list[Path]:
    if recursive:
        return sorted(root.rglob("*.mp3"))
    return sorted(root.glob("*.mp3"))


def reencode_one(src: Path, ffmpeg: str, bitrate: str, overwrite: bool) -> None:
    """동일 경로에 덮어쓰기. 임시 파일에 쓴 뒤 교체."""
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
        tmp_path = Path(tmp.name)
    try:
        cmd = [
            ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(src),
            "-acodec",
            "libmp3lame",
            "-b:a",
            bitrate,
            "-ar",
            "44100",
            "-ac",
            "2",
            str(tmp_path),
        ]
        subprocess.run(cmd, check=True)
        if overwrite:
            tmp_path.replace(src)
        else:
            raise RuntimeError("internal: overwrite=False not used")
    except Exception:
        tmp_path.unlink(missing_ok=True)
        raise


def main() -> int:
    p = argparse.ArgumentParser(description="MP3 일괄 재인코딩 (ffmpeg libmp3lame)")
    p.add_argument(
        "folder",
        type=Path,
        help="대상 폴더",
    )
    p.add_argument(
        "-r",
        "--recursive",
        action="store_true",
        help="하위 폴더까지 *.mp3 검색",
    )
    p.add_argument(
        "--bitrate",
        default="192k",
        help="오디오 비트레이트 (기본: 192k)",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="ffmpeg를 실행하지 않고 대상 파일만 출력",
    )
    args = p.parse_args()

    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg and not args.dry_run:
        print("ffmpeg 를 찾을 수 없습니다. Homebrew 등으로 설치 후 PATH에 넣어 주세요.", file=sys.stderr)
        return 1

    root = args.folder.resolve()
    if not root.is_dir():
        print(f"폴더가 아닙니다: {root}", file=sys.stderr)
        return 1

    files = find_mp3(root, args.recursive)
    if not files:
        print(f"MP3 없음: {root}")
        return 0

    print(f"대상 {len(files)}개 (44100 Hz stereo, {args.bitrate}, libmp3lame)")
    for f in files:
        rel = f.relative_to(root) if f.is_relative_to(root) else f
        print(f"  {rel}")
        if args.dry_run:
            continue
        try:
            reencode_one(f, ffmpeg, args.bitrate, overwrite=True)
        except subprocess.CalledProcessError as e:
            print(f"실패: {f}", file=sys.stderr)
            return e.returncode or 1
        except Exception as e:
            print(f"실패: {f} — {e}", file=sys.stderr)
            return 1

    if not args.dry_run:
        print("완료.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
