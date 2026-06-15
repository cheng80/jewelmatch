# Stone Match Design

## Core Direction

Stone Match uses an ancient fantasy temple UI: obsidian stone, aged brass, teal magic, and restrained red danger accents. The jewels are the brightest objects on screen. UI chrome must support the jewels, not compete with them.

## Visual Hierarchy

1. Gameplay jewels: highest saturation and detail.
2. Primary containers and popups: ornate jeweled stone frame.
3. Buttons: simple brass-and-obsidian frame, no gemstones.
4. Circular icon buttons: simple brass ring, no gemstones.
5. Progress and control rails: dark stone track, brass rim, muted teal active state.
6. Background and board slots: darkest, lowest contrast layer.

## Asset Rules

- Use jeweled frames only for popups, modal panels, and major containers.
- Do not use jeweled frames on buttons, sliders, switches, HUD icons, or small repeated controls.
- Button frames must stay simple: brass edge, dark stone center, no text baked into the asset.
- Nine-patch/stretch areas must avoid ornaments, runes, cracks, and highlight seams.
- Generated PNG assets used by the app must be copied into `assets/images/ui/`.

## Controls

- Sliders represent adjustable power or volume. Use a dark stone rail with a brass outline and muted teal/gold active fill.
- Slider thumbs use gold/brass instead of bright candy colors.
- Switches use dark inactive tracks and muted teal active tracks with gold/brass thumbs.
- Time bars use the same rail grammar as sliders, but larger and more legible.
- Critical time may use red/orange fill, but the rail and border stay brass/stone.

## Text

- Gold labels for headings, section titles, dialog titles, selected states, and secondary actions.
- Teal is reserved for functional or magical state only: active rails, focus rings, special-gem arrows, and temporary loading effects.
- Do not use bright teal/mint for large readable text. It competes with the jewels and weakens the ancient-fantasy tone.
- White text should be warm parchment, not pure white, except for short score flashes or gem effects.
- Celebration effects use brass, muted red, and restrained teal. Avoid candy pink, neon cyan, and saturated purple in UI effects.
- Warm white for score and high-priority numeric readouts.
- Red only for danger, critical time, or destructive emphasis.

## Current Application Map

- Title buttons: simple obsidian button frame.
- Popup and modal panels: jeweled obsidian panel frame.
- Popup buttons: simple obsidian button frame.
- HUD icon buttons: circular brass/obsidian frame.
- HUD time bar and app sliders: stone rail with brass/teal hierarchy.
