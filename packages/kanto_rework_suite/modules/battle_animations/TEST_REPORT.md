# Kanto Rework Battle Animations 0.1.7 — validation report

Evidence boundary: **STATIC/UNIT** for the new enemy-placement merge. No interactive Gen1Recomp battle was executed in this task workspace, so visual/runtime acceptance remains **NOT TESTED**.

## Baseline and scope

- Authoritative base: KRS Battle Animations 0.1.6.
- Contributor source: 0.1.11-BattleArt-Enemy-Placement-Fix, treated as a divergent patch source rather than a replacement package.
- Common historical comparison point: KRS 0.1.4.
- Both supplied manifests target Gen1Recomp `>=0.1.80 <0.2.0`, Mod API 2.
- The merge imports only the semantic enemy fallback placement logic. Contributor Battle Art compositor/blend/plane changes are excluded.

## Implemented in 0.1.7

- Missing-opponent player sequences are classified from visible effect geometry as `target`, `user`, or `reflect`.
- Current authoritative animation data yields 100 fallback moves: **55 target / 18 user / 27 reflect**.
- The contributor-reported attacks (Wrap, Constrict, Fire Spin, Clamp, Bite, Super Fang, Vise Grip, String Shot, Poison Powder, Sleep Powder, Stun Spore, Spore, Smog, Poison Gas, Smokescreen, Toxic, Thunder Wave) all classify `target`.
- Native/fallback 160x96 rendering applies canonical target/user translation or directional reflection.
- KRS Wide target-local effects anchor directly to the current live defender; user-local effects anchor directly to the current live attacker; mixed/directional effects retain the 0.1.6 live attacker→defender projection.
- Dedicated `opp` sequences remain untouched.
- Stage-spanning Wide logic remains unchanged.
- `attack_animations` option, native fallback, `wideLayeringContract=2`, and KRS compositor ordering are preserved.

## Validation performed

- `texluac -p`: **6/6 Lua files PASS**.
- `tests/test_attack_animation_option.lua`: **PASS**.
- `tests/test_enemy_fallback_geometry.lua`: **PASS**.
- `tests/test_enemy_fallback_runtime_unit.lua`: **PASS** — production installer/draw paths exercised deterministically for Wrap (`target`), Recover (`user`), Ember (`reflect`), Absorb (dedicated `opp`) and Earthquake (stage-spanning). This is a UNIT test with stubs, not an interactive Gen1Recomp runtime test.
- Animation inventory: **165 moves / 65 dedicated opponent variants / 100 fallback moves PASS**.
- Fallback classification totals: **55 target / 18 user / 27 reflect PASS**.
- All 17 contributor-reported attack families above: **target-local PASS**.
- `manifest.json` and `BUILD_REPORT.json`: JSON parse **PASS**.
- `data/gen1_anims.lua` and packaged animation/audio assets are not modified by this merge.

## Runtime status

- Actual enemy Wrap/Constrict/Fire Spin/etc. battle playback: **NOT TESTED**.
- KRS Wide live-anchor visual placement: **NOT TESTED**.
- Vanilla/native 160x96 enemy fallback visual placement: **NOT TESTED**.
- Windows/OpenGL/audio hardware behavior: **NOT TESTED**.

Most recent project evidence outside this task records a Gen1Recomp 0.1.94 boot smoke with Battle Animations 0.1.5; that does not validate this 0.1.7 behavior.
