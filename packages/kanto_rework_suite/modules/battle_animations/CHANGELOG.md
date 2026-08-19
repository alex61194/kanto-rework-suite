# Changelog

## 0.1.7 — Semantic enemy fallback placement merge

- Integrates the contributor target/user/reflect geometry classifier into the current KRS 0.1.6 architecture without replacing the 0.1.6 compositor or MODS toggle.
- Enemy attacks with no dedicated `opp` animation are classified from authored visible effect cels: 55 target-local, 18 user-local, 27 mixed/directional among the 100 fallback moves.
- Native/fallback rendering translates target-local and user-local effects between canonical battler anchors while preserving local X/Y offsets; mixed/directional effects use the canonical 180-degree point reflection.
- KRS Wide rendering does **not** pre-transform then re-project: target-local effects anchor directly to the current live defender bounds, user-local effects anchor directly to the live attacker bounds, and mixed/directional effects retain the existing 0.1.6 live attacker→defender projection.
- Dedicated opponent animations remain untouched.
- Stage-spanning Wide effects retain the 0.1.6 full-stage behavior.
- Contributor Battle Art-specific compositor/blend/plane changes are intentionally excluded from this merge because they are independent from the placement fix and come from a divergent rendering branch.

## 0.1.6

- Move Wide Essentials back/front composition into the KRS battle compositor seam so effects cannot paint over KRS global Header/Footer.
- Remap authored user/target positions against current per-frame KRS battler bounds, allowing moved Live Graphics sprites to keep correct projectile/self/target placement.
- Preserve stage-spanning handling for authored full-screen effects such as Surf.


## 0.1.5
- Adds a real Attack Animations toggle in the module options; OFF returns immediately to native Gen1Recomp move animation behavior.
- Preserves the KRS Wide compositor order `KRS_BG -> ANIM_BACK -> KRS_POKEMON -> KRS_HUD -> ANIM_FRONT`.
- Keeps full-screen/stage-spanning move scaling behavior from 0.1.4.

## 0.1.4
- Double-check and harden KRS Wide layering detection.
- The Wide compositor hook no longer requires the observed BattleBackGround source drawable itself to be exactly 1920x950.
- Detect canonical KRS battle backgrounds by final drawn size as well, including scaled sources and quad-drawn backgrounds.
- Keep the stage-spanning cel scaling fix from 0.1.3 intact.

# Changelog

## 0.1.4
- Generalize the Wide full-screen coverage fix beyond Surf.
- Detect stage-spanning Essentials cel layouts and scale them against the full 512px battle stage in KRS Wide battles.
- Static scan of Generation I sources flags Surf, Earthquake and Fissure for this path.
- Opponent-side variants continue to use the same logic; no move mapping, timings or SFX data changed.

# Changelog

## 0.1.4
- Fix player-side Surf in Kanto Rework Wide battles: the wave once again spans the full battle width instead of leaving a large central gap.
- Keep the 0.1.1 Wide layering fix intact.
- Scope the scale override to player-side Surf only; no move mapping, timing or SFX data changed.

# Changelog

## 0.1.4
- Fix Kanto Rework Wide battle layering: move animations no longer render underneath canonical BattleBackGrounds.
- Split Essentials composition into background/back and front/foreground layers around the KRS presenter.
- Keep vanilla/native fallback when KRS UI or its canonical 1920x950 background is not observed.
- No move mapping, timing or SFX data changed.
