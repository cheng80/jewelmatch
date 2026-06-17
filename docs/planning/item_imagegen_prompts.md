# 1차 아이템 이미지 생성 프롬프트

이 문서는 1차 아이템 슬롯용 bitmap 에셋을 `imagegen` 서브 세션에서 다시 생성할 때 쓰는 프롬프트 모음이다.

기준은 현재 채택한 아이템 이미지다. 이전의 저해상도 보석 스프라이트 방향보다, 지금 슬롯에 들어간 고광택 판타지 아이템 이미지의 질감과 구성을 우선한다.

## 기준 이미지

현재 기준 아이콘:

- `assets/images/ui/item_icons/rune_hammer.png`
- `assets/images/ui/item_icons/ancient_bomb.png`
- `assets/images/ui/item_icons/thor_hammer.png`
- `assets/images/ui/item_icons/hyper_cube.png`
- `assets/images/ui/item_icons/prism_transform.png`
- `assets/images/ui/item_icons/fate_shuffle.png`
- `assets/images/ui/item_icons/time_slip.png`
- `assets/images/ui/item_icons/hint_plus.png`

QA 기준 이미지:

- `tmp/qa/item_icons_recleaned_thor_time_contact.png`
- `tmp/qa/item-icons-browser-recleaned.png`

게임 톤 참고:

- `assets/images/backgrounds/ancient_ruins_space_bg.png`
- `assets/images/ui/obsidian_icon_button_frame.png`
- `assets/images/ui/obsidian_panel_frame.png`
- `assets/images/sprites/Jewel_Arcane.png`
- `assets/images/sprites/Special_Arcane.png`

## 생성 목표

현재 채택한 아이템들은 다음 특성이 좋다.

- 큰 실루엣이라 40px 이하 슬롯에서도 알아보기 쉽다.
- 금속 테두리, 보석 장식, 검은 암석/흑요석 재질이 게임 UI와 맞는다.
- 각 아이템마다 색상 정체성이 분명하다.
- 슬롯 프레임 없이도 물건 자체가 프리미엄 보상처럼 보인다.
- 단순 픽셀 스프라이트가 아니라 고광택 판타지 매치-3 아이템 렌더에 가깝다.

따라서 새 생성도 이 방향을 유지한다.

## 공통 프롬프트 블록

각 아이템 프롬프트 앞에 이 블록을 붙인다.

```text
Use case: stylized-concept
Asset type: premium fantasy match-3 mobile game item icon, transparent cutout source
Style/medium: high-polish stylized 3D fantasy game item render, crisp bitmap icon, not vector, not flat pixel art, not painterly key art
Game art direction: match the current Stone Match item icons in assets/images/ui/item_icons: ornate gold bevels, black obsidian stone, carved relic surfaces, embedded faceted jewels, bright controlled magical glow, strong readable silhouette, premium mobile puzzle game finish
Composition/framing: one centered item only, no slot frame, no background scene, object fills 78-88% of the square image, generous padding, readable at 48px
Lighting/mood: dramatic studio-like icon lighting, high contrast, bright rim highlights, controlled glow attached to the item, no cast shadow on the background
Material language: aged gold trim, cracked dark stone, polished gems, glass only where the item requires it, crisp bevels, clean edges
Background: perfectly flat solid #FF00FF chroma-key background for alpha extraction
Constraints: no text, no letters, no numbers, no watermark, no UI frame baked into the icon, no floor, no scene, no gradient background, no shadow on the chroma-key background, do not use #FF00FF in the subject
Avoid: low-detail placeholder, simple line icon, flat vector symbol, realistic photo prop, muddy silhouette, tiny decorative noise, loose particles that will be hard to key out, magenta/pink glow near the edge
```

권장 생성 방식:

- 개별 생성보다 4×2 스프라이트시트 생성이 스타일 통일에 유리하다.
- 단, 한 아이템만 실패하면 해당 아이템만 개별 재생성한다.
- 스프라이트시트 순서는 반드시 아래 순서를 따른다.

| 순서 | 아이템 | 파일명 |
|---:|---|---|
| 1 | 룬 망치 | `assets/images/ui/item_icons/rune_hammer.png` |
| 2 | 고대 폭탄 | `assets/images/ui/item_icons/ancient_bomb.png` |
| 3 | 토르 망치 | `assets/images/ui/item_icons/thor_hammer.png` |
| 4 | 하이퍼 큐브 | `assets/images/ui/item_icons/hyper_cube.png` |
| 5 | 프리즘 변환 | `assets/images/ui/item_icons/prism_transform.png` |
| 6 | 운명 셔플 | `assets/images/ui/item_icons/fate_shuffle.png` |
| 7 | 타임 슬립 | `assets/images/ui/item_icons/time_slip.png` |
| 8 | 힌트+ | `assets/images/ui/item_icons/hint_plus.png` |

## 4×2 스프라이트시트 프롬프트

가장 먼저 이 프롬프트로 한 번 생성한다.

```text
Use case: stylized-concept
Asset type: 4 columns x 2 rows premium fantasy match-3 mobile game item icon spritesheet, transparent cutout source
Primary request: Create a 4x2 spritesheet containing exactly 8 premium Stone Match item icons. Match the current accepted item icon set: ornate gold bevels, black obsidian stone, embedded jewels, crisp high-polish stylized 3D game asset rendering, bright controlled magic glow, strong readable silhouettes, no slot frames.

Icon order, left to right, top row then bottom row:
1. Rune Hammer: chunky black stone hammer with aged gold bands, gold spikes, teal gemstone and cyan rune plate on the head, short bronze handle with teal gem pommel.
2. Ancient Bomb: round cracked obsidian bomb, aged gold cap and fuse ring, red faceted jewel plate on the front, orange lava glow inside cracks, short burning fuse.
3. Thor Hammer: heavy black stone hammer with ornate gold bands, bright blue jewel on the head, cyan lightning energy around the hammer, teal gem pommel, more powerful than Rune Hammer.
4. Hyper Cube: dark purple cosmic cube with gold corner armor, faceted violet crystal panels, starfield core, bright purple internal light.
5. Prism Transform: triangular gold-framed crystal prism, rainbow refracted gemstone interior, sharp gold corner caps, small purple jewel at the base.
6. Fate Shuffle: crossed ornate gold shuffle arrows, four floating faceted gems around it (red, green, blue, purple), clean motion-emblem silhouette.
7. Time Slip: ornate gold hourglass with teal glowing sand, dark metal/glass body, teal gems on top and bottom caps, readable vertical silhouette.
8. Hint Plus: glowing golden bulb or clue orb with ornate gold rim, warm light core, small teal plus medallion attached at lower right.

Style/medium: high-polish stylized 3D fantasy game item render, crisp bitmap icon, not vector, not flat pixel art, not painterly key art.
Game art direction: match the current Stone Match item icons in assets/images/ui/item_icons, plus the game obsidian temple UI. Premium fantasy puzzle item assets, not generic app icons.
Composition/framing: 4 equal columns x 2 equal rows, each item centered in its cell, similar scale, fills 78-88% of each cell, safe padding, no overlaps between cells.
Lighting/mood: dramatic icon lighting, high contrast, controlled glow attached to the item only.
Background: perfectly flat solid #FF00FF chroma-key background across the entire image for alpha extraction.
Constraints: no text, no letters, no numbers, no watermark, no baked slot frames, no background scene, no shadows on the chroma-key background, do not use #FF00FF in any item.
Avoid: simple flat icons, tiny details that disappear in small slots, loose pink/purple glow near object edges, character art, inventory panel background.
```

## 개별 재생성 프롬프트

아래 프롬프트는 특정 아이템만 품질이 낮거나 키 제거가 어려울 때 쓴다.

## 01 룬 망치

```text
Use case: stylized-concept
Asset type: premium fantasy match-3 mobile game item icon, transparent cutout source
Primary request: Create one Rune Hammer item icon matching the current Stone Match item icon set.
Subject: a chunky ancient hammer made of cracked black obsidian stone and aged gold, with gold bands around the head, small gold spikes, a teal gemstone pommel, and a glowing cyan rune plate set into the hammer head.
Style/medium: high-polish stylized 3D fantasy game item render, crisp bitmap icon.
Composition/framing: hammer placed diagonally from lower left to upper right, head large and dominant, handle short and readable, object fills about 84% of the square.
Lighting/mood: premium game icon lighting, gold highlights, controlled cyan rune glow.
Background: perfectly flat solid #FF00FF chroma-key background.
Constraints: no text, no letters, no numbers, no UI frame, no scene, no cast shadow, no watermark, do not use #FF00FF in the subject.
Avoid: modern hammer, flat vector, low-detail stone club, long thin handle, excessive loose glow.
```

## 02 고대 폭탄

```text
Use case: stylized-concept
Asset type: premium fantasy match-3 mobile game item icon, transparent cutout source
Primary request: Create one Ancient Bomb item icon matching the current Stone Match item icon set.
Subject: a round cracked obsidian bomb with aged gold cap, gold fuse ring, red faceted jewel plate on the front, orange lava glow visible through stone cracks, short burning fuse at the top.
Style/medium: high-polish stylized 3D fantasy game item render, crisp bitmap icon.
Composition/framing: centered spherical bomb, front jewel visible, fuse stays inside safe padding, object fills about 82% of the square.
Lighting/mood: warm ember glow from cracks, gold rim highlights, no explosion.
Background: perfectly flat solid #FF00FF chroma-key background.
Constraints: no text, no letters, no numbers, no UI frame, no scene, no smoke, no cast shadow, no watermark, do not use #FF00FF in the subject.
Avoid: cartoon black bomb, grenade, active blast, loose sparks outside the silhouette.
```

## 03 토르 망치

```text
Use case: stylized-concept
Asset type: premium fantasy match-3 mobile game item icon, transparent cutout source
Primary request: Create one Thor Hammer item icon matching the current Stone Match item icon set.
Subject: a heavy black obsidian hammer with ornate aged gold bands, a bright blue faceted jewel on the hammer head, teal gem pommel, and cyan lightning energy wrapping around the head.
Style/medium: high-polish stylized 3D fantasy game item render, crisp bitmap icon.
Composition/framing: diagonal hammer, larger and more powerful than Rune Hammer, head dominates the silhouette, lightning close to the hammer and not far from the object.
Lighting/mood: bright cyan lightning, blue jewel glow, gold rim highlights, high contrast.
Background: perfectly flat solid #FF00FF chroma-key background.
Constraints: no text, no letters, no numbers, no UI frame, no scene, no watermark, no cast shadow, do not use #FF00FF in the subject.
Avoid: superhero branded hammer, far-reaching lightning bolts, magenta/pink lightning, loose particles that make chroma-key cleanup hard.
```

## 04 하이퍼 큐브

```text
Use case: stylized-concept
Asset type: premium fantasy match-3 mobile game item icon, transparent cutout source
Primary request: Create one Hyper Cube item icon matching the current Stone Match item icon set.
Subject: a dark purple cosmic cube with gold corner armor and bevels, faceted violet crystal side panels, starfield-like core, bright purple internal magical light.
Style/medium: high-polish stylized 3D fantasy game item render, crisp bitmap icon.
Composition/framing: centered isometric cube, clear square silhouette, object fills about 82% of the square.
Lighting/mood: contained purple cosmic glow, bright jewel highlights, deep black-violet shadows.
Background: perfectly flat solid #FF00FF chroma-key background.
Constraints: no text, no letters, no numbers, no UI frame, no scene, no watermark, no cast shadow. Avoid using #FF00FF at the outer edge; keep purple item colors clearly darker/bluer than the background key.
Avoid: sci-fi neon cube, plain glass cube, soft blurry galaxy cloud, pink edge glow that will survive key removal.
```

## 05 프리즘 변환

```text
Use case: stylized-concept
Asset type: premium fantasy match-3 mobile game item icon, transparent cutout source
Primary request: Create one Prism Transform item icon matching the current Stone Match item icon set.
Subject: a triangular crystal prism inside ornate aged gold corner caps, rainbow faceted interior with red, yellow, green, blue, and violet sections, small purple jewel at the bottom point.
Style/medium: high-polish stylized 3D fantasy game item render, crisp bitmap icon.
Composition/framing: upright triangle prism, centered, wide base, clear silhouette, object fills about 82% of the square.
Lighting/mood: bright internal rainbow refraction, crisp gold rim highlights, no external rainbow beam.
Background: perfectly flat solid #FF00FF chroma-key background.
Constraints: no text, no letters, no numbers, no UI frame, no scene, no watermark, no cast shadow, do not use #FF00FF in the subject.
Avoid: flat triangle icon, realistic transparent glass only, rainbow background, tiny shard noise.
```

## 06 운명 셔플

```text
Use case: stylized-concept
Asset type: premium fantasy match-3 mobile game item icon, transparent cutout source
Primary request: Create one Fate Shuffle item icon matching the current Stone Match item icon set.
Subject: two crossed ornate aged-gold shuffle arrows forming an X-like motion emblem, surrounded by four floating faceted gems: red, green, blue, and purple.
Style/medium: high-polish stylized 3D fantasy game item render, crisp bitmap icon.
Composition/framing: centered emblem, arrows large and readable, four gems placed around the arrows with balanced spacing, object group fills about 84% of the square.
Lighting/mood: warm gold highlights, jewel sparkle, controlled glow only on gems.
Background: perfectly flat solid #FF00FF chroma-key background.
Constraints: no text, no letters, no numbers, no UI frame, no scene, no watermark, no cast shadow, do not use #FF00FF in the subject.
Avoid: flat app shuffle symbol, thin arrows, casino objects, too many tiny gems, motion blur.
```

## 07 타임 슬립

```text
Use case: stylized-concept
Asset type: premium fantasy match-3 mobile game item icon, transparent cutout source
Primary request: Create one Time Slip item icon matching the current Stone Match item icon set.
Subject: an ornate gold hourglass relic with teal glowing sand, dark glass body, gold top and bottom caps, teal faceted gems embedded on the caps.
Style/medium: high-polish stylized 3D fantasy game item render, crisp bitmap icon.
Composition/framing: centered upright hourglass, broad readable silhouette, object fills about 82% of the square, all columns and caps thick enough for small slots.
Lighting/mood: teal sand glow inside the hourglass, warm gold highlights, no external particles.
Background: perfectly flat solid #FF00FF chroma-key background.
Constraints: no text, no letters, no numbers, no UI frame, no scene, no watermark, no cast shadow, do not use #FF00FF in the subject.
Avoid: realistic delicate glassware, clock face, stopwatch, thin fragile lines, pink edge glow.
```

## 08 힌트+

```text
Use case: stylized-concept
Asset type: premium fantasy match-3 mobile game item icon, transparent cutout source
Primary request: Create one Hint Plus item icon matching the current Stone Match item icon set.
Subject: a glowing golden clue bulb or orb inside an ornate gold rim, warm light core with visible filament shape, black/gold base, small teal circular plus medallion attached at lower right.
Style/medium: high-polish stylized 3D fantasy game item render, crisp bitmap icon.
Composition/framing: centered bulb/orb with plus medallion, large clear silhouette, object fills about 84% of the square.
Lighting/mood: warm golden glow contained inside the bulb, teal plus accent, bright gold rim highlights.
Background: perfectly flat solid #FF00FF chroma-key background.
Constraints: no text, no letters, no numbers, no UI frame, no scene, no watermark, no cast shadow, do not use #FF00FF in the subject.
Avoid: modern flat lightbulb icon, medical plus sign style, question mark, excessive external halo.
```

## 키 제거 및 후처리

기본 키 색은 현재 기준 이미지처럼 `#FF00FF`를 쓴다. 생성 후 원본은 `tmp/imagegen/` 또는 작업 세션의 임시 위치에 보관하고, 최종 PNG만 `assets/images/ui/item_icons/`에 둔다.

일반 키 제거:

```bash
python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
  --input <source.png> \
  --out <final.png> \
  --key-color '#FF00FF' \
  --soft-matte \
  --transparent-threshold 18 \
  --opaque-threshold 210 \
  --edge-contract 1 \
  --despill \
  --force
```

`thor_hammer.png`, `time_slip.png`처럼 외곽에 키 컬러가 남기 쉬운 이미지는 더 강하게 정리한다.

```bash
python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
  --input <source.png> \
  --out <final.png> \
  --key-color '#FF00FF' \
  --soft-matte \
  --transparent-threshold 28 \
  --opaque-threshold 190 \
  --edge-contract 2 \
  --despill \
  --force
```

검수 기준:

- 256×256 원본에서 외곽에 마젠타 잔여가 없어야 한다.
- 어두운 배경 contact sheet에서 외곽 fringe가 보이면 실패다.
- 48px 슬롯 크기에서 아이템 종류가 바로 구분되어야 한다.
- `thor_hammer`의 번개는 cyan/blue 계열이어야 하며 pink/magenta 계열 번개는 피한다.
- `hyper_cube`는 보라색을 써도 되지만 외곽 키 색 `#FF00FF`와 섞이면 안 된다.
- 슬롯 프레임, 텍스트, 숫자, 배경 장면을 이미지에 포함하지 않는다.

## 서브 세션 작업 지시문

```text
Use the imagegen skill. Regenerate the 8 Stone Match item icons using docs/planning/item_imagegen_prompts.md. Match the current accepted icon style in assets/images/ui/item_icons: high-polish fantasy item renders with ornate gold, obsidian stone, faceted jewels, strong silhouettes, and controlled glow. Prefer one 4x2 spritesheet first for style consistency. Use a flat #FF00FF chroma-key background. After generation, split into 8 final alpha PNGs named exactly as listed in the document under assets/images/ui/item_icons/. Remove chroma-key carefully, especially thor_hammer and time_slip. Verify on a dark contact sheet and at 48px slot size. Do not include slot frames, labels, numbers, or background scenes.
```
