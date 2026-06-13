# New Gem Design Review

Date: 2026-06-13

## Goal

Replace the current normal gem sprites that are visually close to Bejeweled 3 with an original Jewel Match design language.

The current runtime uses:

- Normal gems: `assets/images/sprites/Jewel.png`, 7 cells, `896x128`, each cell `128x128`.
- Special gems: `assets/images/sprites/Special.png`, 3 cells, `384x128`, each cell `128x128`.
- Runtime render size: about `0.82 * tileSize`, centered in each board tile.

## Generated Concepts

All three concepts are ImageGen exploration sheets, not final runtime sprite sheets.

| Option | File | Direction |
| --- | --- | --- |
| 1 | `docs/design/new_gem_concepts/option-1-candy-lumina-relics.png` | Premium candy relics, strong silhouette variety, ornate specials |
| 2 | `docs/design/new_gem_concepts/option-2-prismatic-toy-stones.png` | Chunky toy-like translucent stones, best small-size readability |
| 3 | `docs/design/new_gem_concepts/option-3-arcane-mineral-charms.png` | Magical carved mineral charms, strongest IP distance |
| 3c | `docs/design/new_gem_concepts/option-3c-arcane-mineral-charms-size-spacing-only.png` | Option 3 direction preserved, with size and spacing normalized |
| 3d specials | `docs/design/new_gem_concepts/option-3d-specials-square-cell-fit.png` | Option 3 special gems revised to fill `128x128` cells without bar-like silhouettes |

## Review

### Option 1: Candy Lumina Relics

Best for: a polished Korean casual puzzle identity with premium charm.

Strengths:

- Strongest normal-gem silhouette spread among the readable options.
- Good color separation and strong visual identity.
- Moves away from classic faceted gem language.

Risks:

- Special gems are over-ornate for `128x128` cells.
- Gold frames may become noisy once scaled down in-game.

Verdict: good candidate, but simplify special gems before production.

### Option 2: Prismatic Toy Stones

Best for: immediate mobile readability and broad casual appeal.

Strengths:

- Clearest at small size.
- Simple material language, easy to convert into clean sprite cells.
- Most practical for fast replacement of `Jewel.png`.

Risks:

- Some special-gem stripe language still feels close to common match-3 conventions.
- Needs stronger brand specificity so it does not become generic candy-game art.

Verdict: safest production base for normal gems; redesign specials.

### Option 3: Arcane Mineral Charms

Best for: maximum IP distance and a more original fantasy identity.

Strengths:

- Least similar to Bejeweled-style gemstone cuts.
- Carved charm language is distinctive.
- Special gems can become a clear Jewel Match signature if simplified.

Risks:

- Rune and crack details may collapse at board scale.
- The overall mood is heavier than the current candy-lumina UI.

Verdict: strongest originality. The original concept direction should be preserved; only size, spacing, and cell fit should be corrected.

### Option 3c: Arcane Mineral Charms, Size/Spacing Pass

Best for: the selected direction for the next sprite-production pass.

Strengths:

- Keeps the original Option 3 carved mineral/rune-stone feel.
- Improves optical size consistency across the normal gems.
- Keeps the rough stone silhouettes and avoids the over-ornate equipment look from the rejected 3b pass.

Risks:

- The horizontal special gem remains wider by design; when composing `Special.png`, it should still be centered in a `128x128` cell and reviewed in-game.
- Fine rune grooves may need simplification after actual 128px alpha extraction.

Verdict: current preferred visual target.

### Option 3d Specials: Square Cell Fit

Best for: replacing the vertical, horizontal, and bomb special gems without wasting space inside `128x128` cells.

Strengths:

- Solves the long-bar problem from 3c specials: the outer silhouette fills the square cell, while the inner rune/light channel communicates vertical or horizontal effect.
- Preserves the Option 3 carved mineral charm style.
- The `384x128` preview reads as three similarly weighted special gems.

Risks:

- The internal rune glow may need simplification after alpha extraction so it does not become noisy in-game.

Verdict: use this as the special-gem direction paired with 3c normal gems.

## Recommendation

Proceed with Option 3c as the visual target. Keep the Option 3 concept language intact and enforce only production geometry: consistent size, consistent padding, and clean cell fit.

Production constraints for the next pass:

- Generate each normal gem as an isolated `128x128` transparent-ready cell.
- Keep one bold internal motif per gem, not multiple tiny grooves.
- Preserve the carved mineral charm/rune-stone look from Option 3c.
- Do not add gold hardware, vines, straps, mechanical parts, badges, or framed equipment details.
- Avoid classic faceted diamond/triangle/octal silhouettes where possible.
- Use the 3d special-gem approach: broad square-cell-filling outer silhouettes, with vertical/horizontal behavior shown by the inner rune/light channel instead of by a long bar-shaped gem.
- Use `sprite-gen`-style QA before integration: alpha cleanup, per-cell extraction, `Jewel.png`/`Special.png` composition, and in-game screenshot review.

## Next Sprite-Gen Plan

The final asset pass should create a new run folder, for example:

```text
assets/generated/sprites/new_gems/
```

Expected deliverables:

- `sprite-request.json`
- isolated transparent gem frames
- composed `Jewel.png` candidate, 7 cells, `896x128`
- composed `Special.png` candidate, 3 cells, `384x128`
- QA contact sheet
- in-game board screenshot comparison
