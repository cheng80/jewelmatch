#!/usr/bin/env python3
"""여러 PNG(또는 그 안의 칸)를 한 장의 텍스처 아틀라스로 묶는다.

픽셀은 리샘플 없이 그대로 복사한다. 칸 가장자리는 padding만큼 바깥 픽셀을 늘려(extrude)
필터링 때 이웃 칸 색이 번지지 않게 한다. 결과는 PNG 한 장과 frames 좌표 JSON이다.

설정 JSON 예:
{
  "output": "assets/images/sprites/board_atlas.png",
  "manifest": "assets/images/sprites/board_atlas.json",
  "padding": 2,
  "maxWidth": 2048,
  "powerOfTwo": true,
  "sources": [
    {"name": "badge_time", "file": "assets/images/sprites/Gem_Badges.png", "rect": [0, 0, 128, 128]},
    {"prefix": "gem_", "file": "assets/images/sprites/Jewel_Arcane.png", "cell": [128, 128], "count": 7}
  ]
}
grid 소스는 이름이 prefix + 0부터의 번호다(가로 우선, columns 생략 시 이미지 폭 / 칸 폭).
powerOfTwo(기본 true)가 false면 결과 크기를 2의 거듭제곱 대신 align의 배수로 올린다.
align(기본 1)은 칸 시작 좌표와 결과 크기를 이 값의 배수로 맞춘다. 칸 크기도 이 값의 배수면
밉맵 단계 log2(align)까지 칸 안쪽 텍셀이 원본 시트와 같게 평균된다(예: 16이면 1/16 축소까지).
홀수 폭 단계가 생기면 밉맵 필터가 칸 경계를 넘으므로 결과 크기도 맞춘다.

사용: python3 tools/pack_atlas.py 설정.json [--check]
--check는 파일을 쓰지 않고 결과 크기와 칸 수만 출력한다.
"""
import json
import sys

from PIL import Image


def load_sources(config):
    items = []
    cache = {}
    for src in config["sources"]:
        path = src["file"]
        if path not in cache:
            cache[path] = Image.open(path).convert("RGBA")
        image = cache[path]
        if "rect" in src:
            x, y, w, h = src["rect"]
            items.append((src["name"], image.crop((x, y, x + w, y + h))))
        else:
            cw, ch = src["cell"]
            columns = src.get("columns") or image.width // cw
            count = src.get("count") or columns * (image.height // ch)
            for i in range(count):
                x = (i % columns) * cw
                y = (i // columns) * ch
                items.append((src["prefix"] + str(i), image.crop((x, y, x + cw, y + ch))))
    names = [n for n, _ in items]
    dup = {n for n in names if names.count(n) > 1}
    if dup:
        raise SystemExit("중복 이름: " + ", ".join(sorted(dup)))
    return items


def pack(items, padding, max_width, power_of_two=True, align=1):
    # 높이 내림차순 선반(shelf) 배치. 칸 크기가 몇 종류뿐이라 이 정도면 충분하다.
    order = sorted(items, key=lambda it: (-it[1].height, -it[1].width, it[0]))

    def up(v):
        return -(-v // align) * align

    placements = {}
    x = y = shelf_h = 0
    width = 0
    for name, img in order:
        if up(padding) + img.width + padding > max_width:
            raise SystemExit(f"{name} 폭 {img.width}이 maxWidth를 넘는다")
        if up(x + padding) + img.width + padding > max_width:
            x = 0
            y += shelf_h
            shelf_h = 0
        ox = up(x + padding)
        oy = up(y + padding)
        placements[name] = (ox, oy, img)
        x = ox + img.width + padding
        shelf_h = max(shelf_h, oy + img.height + padding - y)
        width = max(width, x)
    height = y + shelf_h

    def pow2(v):
        p = 1
        while p < v:
            p *= 2
        return p

    if not power_of_two:
        return placements, up(width), up(height)
    return placements, pow2(width), pow2(height)


def extrude(atlas, x, y, img, padding):
    atlas.paste(img, (x, y))
    w, h = img.size
    for p in range(1, padding + 1):
        atlas.paste(img.crop((0, 0, w, 1)), (x, y - p))
        atlas.paste(img.crop((0, h - 1, w, h)), (x, y + h - 1 + p))
    for p in range(1, padding + 1):
        col_l = atlas.crop((x, y - padding, x + 1, y + h + padding))
        col_r = atlas.crop((x + w - 1, y - padding, x + w, y + h + padding))
        atlas.paste(col_l, (x - p, y - padding))
        atlas.paste(col_r, (x + w - 1 + p, y - padding))


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    config = json.load(open(sys.argv[1], encoding="utf8"))
    check = "--check" in sys.argv
    padding = int(config.get("padding", 2))
    items = load_sources(config)
    placements, width, height = pack(
        items,
        padding,
        int(config.get("maxWidth", 2048)),
        bool(config.get("powerOfTwo", True)),
        int(config.get("align", 1)),
    )
    print(f"{len(items)} frames -> {width}x{height}")
    if check:
        return
    atlas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    frames = {}
    for name, (x, y, img) in sorted(placements.items()):
        extrude(atlas, x, y, img, padding)
        frames[name] = {"x": x, "y": y, "w": img.width, "h": img.height}
    atlas.save(config["output"], optimize=True)
    image_name = config["output"].split("/")[-1]
    manifest = {"image": image_name, "size": [width, height], "padding": padding, "frames": frames}
    with open(config["manifest"], "w", encoding="utf8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    # 원본 칸과 아틀라스 칸이 픽셀 단위로 같은지 확인한다.
    for name, (x, y, img) in placements.items():
        if atlas.crop((x, y, x + img.width, y + img.height)).tobytes() != img.tobytes():
            raise SystemExit(f"{name} 픽셀 불일치")
    print("pixel check ok")


if __name__ == "__main__":
    main()

