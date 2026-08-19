# Kanto Rework Battle Animations 0.1.7

Target: Gen1Recomp 0.1.80, Mod API 2, Generation I.

## Coverage

- 165/165 Generation I moves have direct `Move:<MOVE>` source animations in `PkmnAnimations.rxdata`.
- 65 also have dedicated `OppMove:<MOVE>` variants.
- 214 referenced SFX files are packaged; every sound timing referenced by the selected Gen I animations resolved successfully.
- 116 referenced animation/foreground/background PNGs are packaged.

## Runtime strategy

The mod keeps Gen1Recomp's native battle logic and animation queue. For mapped Generation I move IDs it delegates visual playback to an Essentials-compatible 20 fps player (3 Gen1Recomp fixed frames per source frame). Non-move internal animations such as Poké Ball toss/send-out continue through Gen1Recomp's native `AnimPlayer`.

The bridge uses `engine_internals` because Gen1Recomp 0.1.80's public `battle_anims` registry models the native 8x8 Gen I animation format and cannot represent Essentials' 192x192 cels, per-cel transforms and BG/FG planes without a custom player.

## Validation status

Static conversion and asset resolution are validated. Lua syntax/module loading is tested separately in this build. Visual parity for all 165 moves still requires real in-game qualification, especially SGB/wide battle rendering and unusual blend/tone effects.

## 0.1.4 Wide BattleBackGround layering fix

When `kanto_rework_ui` owns a Wide battle, its canonical 1920x950 BattleBackGround is drawn in the screen-space `render.hud` pass after Gen1Recomp's native BattleState canvas. Version 0.1.0 therefore put Essentials particles under the KRS background.

0.1.4 adds a scoped compositor bridge: the Essentials background/back-priority layer is injected immediately after the canonical BattleBackGround draw; KRS then draws its Pokemon/HUD; Essentials front-priority particles and foreground are drawn afterward. Unsupported/non-KRS presenters keep the existing native fallback.
## 0.1.4 Surf Wide fix

Player-side Surf in 0.1.1 still used the generic Wide particle scale that keeps most move cels visually relative to the battler box. Surf is different: its two source wave cels were authored to meet seamlessly across the native 512px battle stage. In KRS Wide this left a large uncovered strip in the middle of the screen.

0.1.4 keeps the 0.1.1 layering path and applies a move-specific Wide scale override only for player-side Surf, using the Wide stage scale so the wave again spans the battle width. Opponent-side Surf already uses its dedicated foreground plane and was not changed.


## 0.1.4 stage-spanning move fix

0.1.2 corrected Surf with a move-specific Wide scale override. That was too narrow. The real issue is broader: some Essentials move animations lay out multiple cels across the entire native 512px battle stage rather than keeping them relative to the battler box. In KRS Wide, those source layouts must use the stage scale or they leave empty gaps.

0.1.4 replaces the Surf-specific exception with a stage-spanning layout detector. For Generation I source animations, the static scan currently flags `SURF`, `EARTHQUAKE` and `FISSURE`. The same logic also applies to opponent-side variants if any future source animation matches the same layout pattern.

## 0.1.4 Wide background detection hardening

Some missing animations can still happen even when the layering logic itself is correct: the 0.1.3 hook only activated when the observed background drawable reported a raw size of exactly 1920x950. If KRS draws a battle background from a scaled source image, a Canvas, or a Quad viewport, that exact-match test can miss it and the move animation falls back to the native path underneath the Wide background.

0.1.4 keeps the same compositing order but broadens detection: the hook now also recognizes battle backgrounds whose **final drawn size** matches the canonical 1920x950 KRS battle area, including quad-based draws.
## Enemy fallback placement (0.1.7)

When an imported move has no dedicated opponent sequence, KRS classifies its visible authored effect cels as target-local, user-local, or mixed/directional. Target/user-local effects keep their local screen-space offsets around the live defender/attacker respectively; mixed effects keep the existing directional projection. Dedicated opponent sequences are not modified. This avoids enemy Wrap/Constrict/Fire Spin/Clamp/Bite/Super Fang/Vise Grip/String Shot/powders/spores/gases/Toxic/Thunder Wave effects being displaced above the player in the Wide live-anchor path.

