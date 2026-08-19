# Kanto Rework Compatibility 0.4.20

## 0.4.20 — Graphics nomenclature correction
- Corrects historical `Visuals` wording to the canonical Kanto Rework Graphics module name; no new module or dependency is introduced.

## 0.4.19 — Legacy Voxel settings de-duplication

- Keeps Voxel adapters as optional compatibility only; KRS Graphics is the primary owner of battle Pokémon art.
- Removes duplicate Compatibility Scale/Real Size rows while retaining legacy adapter APIs for older mixed installations.
- Removes 0.25x from the legacy scale ladder and migrates an old stored 0.25x value to 0.5x.
- Preserves renderer-health battle ownership: KRS Battle Backgrounds are hidden only for an actually staged/available 3D battle renderer.

## 0.4.18 — Renderer-health battle ownership and Voxel adapter syntax repair

- Stops treating an installed/enabled Voxel mod as sufficient proof that it owns the battle environment.
- Requires the exact staged BattleState and, when exposed by the Voxel family, checks `Voxel3D.available()` and the live staged shot before hiding KRS Battle Backgrounds.
- Keeps KRS backgrounds active when the renderer reports unavailable or the staged shot does not exist; preserves backward compatibility for older family members that do not expose those health seams.
- Exposes a diagnostic reason (`no_staged_battle`, `renderer_unavailable`, `battle_shot_unavailable`, `live_3d_battle`, etc.) for the ownership decision.
- Repairs an inherited Lua syntax defect in the 1.7.9 adapter (`;;` after the Field Move bridge call).
- Adds regression coverage for renderer-health arbitration.

# Kanto Rework Compatibility 0.4.17

## 0.4.17 — Exclusive Voxel 3D battle-environment ownership

- Uses DramaticShapeVoxelMod's public `OverworldBattle.battle()` seam to identify the exact BattleState currently staged in its 3D battle environment.
- Gives that live staged session exclusive visual priority over KRS BattleBackGrounds without mutating Voxel settings, KRS settings, save data or subsequent fights.
- Restores KRS BattleBackGround ownership automatically whenever 3D-BTL is off, arena/session creation did not occur, the queried battle is not the staged one, or the Voxel session has ended.
- Keeps Pokémon sprite-provider ownership independent from background ownership and retains the 1.9.2 pipeline-eligibility pointer guard from 0.4.16.
- Updates the Voxel 1.9.2 audit metadata to the official tag commit.

# Kanto Rework Compatibility 0.4.16

## 0.4.16 — Voxel 1.9.2 audit + unavailable-pipeline guard

- Audits Battle Art Voxel Fork 1.9.2 against Gen1Recomp 0.1.90.
- KRS pointer/field-move arbitration now requires the engine `Pipelines.eligible("voxel")` gate before treating 1ST/3RD as a live 3D pointer surface.
- Does not modify or replace Voxel rendering; Voxel remains the sole owner of mesh generation and the `drawWorld` canvas.

# Kanto Rework Compatibility 0.4.15

## 0.4.15 — Voxel 1.9.0 free-camera pointer arbitration

- Audits the supplied Battle Art Voxel Fork 1.9.0 package and updates the compatibility metadata accordingly.
- Guards Voxel's late `setRelativeMode(true)` recapture only while an interactive KRS surface owns the pointer in 1ST/3RD modes.
- Restores the original LÖVE relative-mode seam on unload and leaves uncovered Voxel camera control untouched.

# Kanto Rework Compatibility 0.4.14

## 0.4.14 — Gen1Recomp 0.1.86 sandbox-safe interoperability

- Migrates all Compatibility-owned modules to `mod:read()` + sandbox-bound `load()` and removes private `_G` bridges.
- Reads KRS UI/Dev pointer ownership only through `mod.find(...).exports`.
- Replaces forbidden LÖVE mouse-callback monkey patches with an `input.step` arbitration pass while Gen1Recomp's public `input.pointer` seam owns physical mouse/touch delivery.
- Keeps Voxel first/third-person relative capture untouched on the passive overworld and releases it only while an explicit KRS surface owns the pointer.
- Preserves Voxel shiny dataset routing, native-frame scaling policy, provider ownership and contextual Cut/Surf integration without modifying any third-party source.

## 0.4.13 — Native Voxel scale semantics and Compatibility-owned controls

- Moves KRS sprite presentation controls off the Battle Art Voxel card and onto Kanto Rework Compatibility.
- UPSCALE is now literal: DEFAULT=x1 native authored frame, X0.25, X0.5, X2 and X3 are exact pixel multipliers; AUTO is the only computed mode.
- Replaces POKÉDEX-SIZED POKÉMON with POKÉMON REAL SIZE = NO / YES / AUTO, consumed by AUTO scaling.
- AUTO derives a per-Pokémon multiplier from native frame dimensions, Pokédex height policy and front/back perspective.
- Explicit shiny battle Pokémon resolve the Voxel generation-specific shiny dataset before the normal live battler image, including Battle Art Voxel 1.8.7 family builds.

## 0.4.12 — Voxel scale policy + authoritative shiny dataset

- Adds `UPSCALE` (`DEFAULT`, `X2`, `X3`) to the Voxel mod section managed by KRS Compatibility.
- Adds `POKÉDEX-SIZED POKÉMON`, active only in DEFAULT upscale mode.
- Exposes the battle-art presentation policy to KRS UI.
- Resolves Gen5 shiny animation definitions from Voxel's own `animated_battle_sprites_gen5_shiny` dataset before any fallback path reconstruction.

## 0.4.11 — Explicit Gen5 shiny atlas routing

- Explicit `mon.shiny == true` now gets first refusal from the Voxel `front-animated/gen5/shiny` atlas while preserving Voxel's frame cells, timing and metrics.
- Prevents the shiny VFX/state from being paired with a normal opponent sprite when the Voxel runtime derives shiny status differently from KRS/debug state.
- Falls back to Voxel's normal live resolver when no matching shipped shiny atlas exists.

## 0.4.10 — Live Voxel animation ownership

- Fixed animated Voxel Pokémon being reset/frozen by per-render `BattleArt.apply` calls.
- Live battles now reuse the real battler sprite and only rebuild provider art when settings or battler identity change.
- Menu and overlay preview battles apply once per visual fingerprint and advance only through `AnimatedBattleArt.update`.

## 0.4.9 — Voxel camera/pointer arbitration

- Changes KRS/Voxel ownership from “overlay visible” to “interactive surface active”.
- Preserves relative mouse camera look under passive F8 overlays while keeping menu, battle, overlay-edit and Dev surfaces mouse-accessible.
- Keeps all third-party code untouched; the change lives only in Kanto Rework Compatibility/UI seams.

## 0.4.8 — Overworld overlay and video-mode cursor continuity

- Extends the Voxel pointer bridge to interactive KRS modular overlays while
  the overworld remains the top state.
- Re-wraps a replaced `love.mouse.setVisible` seam after fullscreen/windowed
  recreation and blocks late camera hides after genuine mouse intent.
- Keeps uncovered overworld capture and controller-only cursor visibility
  under native Voxel policy.

## 0.4.7 — Voxel pointer visibility and shiny menu art

- Guards LOVE cursor visibility as well as relative mode while a mouse-owned
  KRS surface covers Voxel 1ST/3RD navigation, including late third-party
  visibility writes after pointer routing.
- Leaves controller-only cursor policy and uncovered overworld capture under
  Voxel ownership, and restores every wrapped callback during unload.
- Forwards a cloned real Pokémon record to the live Voxel BattleArt preview so
  shiny state/DVs survive Party, Pokédex, PC and starter/menu resolution.
- Keys preview caches by Pokémon identity and shiny/DV signature to prevent a
  normal sprite from being reused for a shiny Pokémon of the same species.

## 0.4.6 — Contract-driven provider families

- Removes exact-version activation gates for Kanto Ascendant, SFX Music Replacement and Dynamic Cries. Audited versions remain metadata only.
- Removes third-party version ceilings from optional dependencies for Ascendant and SFX Music Replacement; KRS internal dependency bounds remain unchanged.
- Replaces the Ascendant 6.0.11-only route with a family adapter gated independently by the live menu and Crystal-art export contracts.
- Discovers SFX Music Replacement from stable identity + standard options + `music.select`/audio-registry ownership, and Dynamic Cries from repository identity + live cry-registry ownership.
- Discovers previously unknown Pokémon sprite providers from the engine's `pokemon.sprite` hook ownership. The selected owner runs alone against the immutable Gen1 terminal fallback, preserving strict exclusivity.
- Migrates the old `stadium_dynamic_cries.1_4_3` preference to the stable `stadium_dynamic_cries` provider id.
- Records Battle Art Voxel Fork 1.8.6 as the latest audited family release; the family adapter remains contract-gated rather than version-gated.
- Adds future-version and unknown-provider regression coverage plus real Gen1Recomp 0.1.80 AppImage integration coverage.

## 0.4.5 — Strict exclusive Pokémon sprite ownership

- Fixed a regression where a selected `pokemon.sprite_art` provider could return no art and silently fall through to Core's global `pokemon.sprite` hook chain. With Kanto Ascendant installed, that chain could reassert Crystal sprites even while Compatibility explicitly selected Voxel or Gen 1.
- Exclusive sprite ownership is now terminal on KRS surfaces. The selected provider either supplies its art or falls back to the immutable Gen 1 species path; a non-selected sprite mod is never consulted implicitly.
- Voxel remains authoritative for its own Battle Art settings/resolution. Its missing/ROM fallback stays owned by the Voxel capability and cannot become Ascendant art.
- Added a three-provider regression test covering Voxel -> Ascendant -> Voxel switching and a deliberate Voxel ROM/missing-art fallback.
- Audited the actual Voxel 1.8.5 change: `DUPLICATE FIX: MODDED` deliberately yields other-mod/ROM ownership on missing art. Compatibility now treats that as a terminal Gen-I fallback on KRS surfaces when Voxel is the explicitly selected provider, so Ascendant cannot silently win.

## 0.4.4 — Voxel selected sprite provider regression

- Restores the selected Battle Art Voxel sprite provider on both KRS battle and shared menu surfaces after the 1.8.4 Battle Art expansion.
- Resolves Voxel art through the live public BattleArt / AnimatedBattleArt runtime first, so species aliases, shiny sets and generation routing stay owned by Voxel instead of being reimplemented by Compatibility.
- Keeps the previous hand-decoder only as a compatibility fallback when the live resolver cannot provide an image.
- Adds a regression test that switches Gen 1 -> Voxel and verifies both menu-front and player-battle art follow the Compatibility selection.

## 0.4.3 — Global Options ownership cleanup

- Moves custom `ui.options.rows` duplicates such as SFXMusicReplacementMod SOUNDTRACK / SOUND EFFECTS / STEREO SOUND out of global Options when their ownership is proven by the live standard schema.
- Removes duplicate mod-owned render-pipeline rows from global Options when the owning mod already exposes the equivalent setting through its schema.
- Keeps native engine rows untouched unless mod provenance is actually established.
- The rule is schema/provenance-driven and does not depend on a third-party version number or hard-coded option list.

## 0.4.1 — Explicit Gen 1 art + audited audio domains

- Makes GEN 1 SPRITES a true explicit KRS provider by reading the immutable species front/back paths instead of the live `pokemon.sprite` hook chain; selecting Gen 1 therefore cannot silently show Ascendant/Voxel art in Party, Pokédex, PC or battle.
- Keeps Voxel 1.8.3 and Kanto Ascendant 6.0.11 as alternate providers under the same `POKéMON SPRITES` capability.
- Audits SFX Music Replacement 2.0.0 as music/general-SFX ownership and Dynamic Cries 1.4.3 as Pokémon-cry ownership; those two known packages do not conflict because they own different domains.
- Adds versioned Dynamic Cries detection by repository + manifest version when that package is installed, without guessing or patching its mod id.
- Conflict selectors remain capability-driven and appear only when multiple active mod providers actually claim the same domain.

## 0.4.0 — Unified Pokémon visual ownership

- Adds exclusive `POKéMON SPRITES` ownership with Gen 1, Battle Art Voxel 1.8.3 and Kanto Ascendant 6.0.11 providers. The selected provider now feeds both KRS battle presentation and every shared KRS Pokémon-art surface.
- Adds a read-only Voxel 1.8.3 menu/battle art resolver using its public BattleArt data/settings while preserving the mod's own generation, animation and PLAYER FRONT/BACK choices.
- Extends the Ascendant 6.0.11 provider to KRS front and back presentation while preserving its Crystal/animation options.
- Declares SFX and Pokémon-cry conflict domains and registers SFX Music Replacement 2.0.0 for its verified music/SFX capabilities.
- Keeps Voxel Battle Background ownership independent from Pokémon sprite ownership, so KRS backgrounds can coexist with Voxel sprite choices.

## 0.3.9 — Real-time Voxel Battle Art clock

- Keeps Battle Art Voxel 1.8.3 animated front/back/player atlases at their authored real-time cadence even when Gen1Recomp accelerates BattleState logic.
- Applies the same clock when 3D-BTL is OFF so KRS backgrounds can coexist with animated Voxel sprites without freezing or speeding them up.
- Exposes Voxel authored-cell plus anchor metrics read-only so UI can keep successive animation frames at a stable visual scale.
- Leaves the third-party mod and all of its persisted sprite/art choices untouched.

## 0.3.7 — Battle ownership + inline third-party settings

- Adds explicit battle-background ownership between KRS and Battle Art Voxel 1.8.3.
- Preserves Voxel-selected Pokémon and trainer Battle Art even when KRS owns WHITE/BLACK battle backgrounds.
- Moves Voxel pipeline/native settings into its expanded Mods entry and removes duplicate global Options rows.
- Exposes real multi-provider conflicts as selectors under Kanto Rework Compatibility.

## 0.3.6 — Battle Art Voxel 1.8.3 compatibility

- Adds an exact adapter for `BATTLE_ART_VOXEL_FORK` 1.8.3 (`12d142a`).
- Restores the existing KRS pointer-release bridge in Voxel 1ST/3RD menus;
  Compatibility 0.3.5 intentionally matched only 1.7.9, so updating the third-
  party mod disabled that bridge entirely.
- Restores automatic contextual Cut/Surf while 1.8.3 FreeMove owns walking by
  reusing the unchanged exported `FirstPerson` / `FreeMove` contracts.
- Keeps both supported third-party releases byte-for-byte untouched and does
  not widen matching to unaudited Voxel versions.

## 0.3.5 — Canonical Voxel input and Field Move bridge

- Routes captured 1ST/3RD mouse movement and click sequences through Core's
  real pointer pipeline, restoring KRS Hover and pointer-device promotion.
- Reasserts the outer callback bridge after all mods initialize instead of
  assuming a fixed callback-installation order.
- Restores automatic Cut and Surf while Voxel FreeMove owns overworld walking
  by reusing its public world vector/collision query and Gameplay's registered
  Core field actions; Strength and Flash keep their existing native seams.
- Keeps DramaticShapeVoxelMod 1.7.9 byte-for-byte untouched.

## 0.3.4 — Voxel 1ST/3RD menu pointer bridge

- Prevents Battle Art Voxel Fork 1.7.9 from re-enabling LOVE relative mouse
  mode while a KRS pointer surface owns the screen.
- Routes mouse movement and complete press/release sequences directly to the
  Gen1Recomp pointer seam while the mod's private capture flag remains active.
- Restores original Voxel camera ownership immediately after returning to the
  overworld and preserves world-originated button releases across transitions.
- Keeps the third-party archive and source unchanged.

## 0.3.3 — Battle Art Voxel 1.7.9 integration

- Adds an exact adapter for `BATTLE_ART_VOXEL_FORK` 1.7.9 (`791bebc`).
- Removes Battle Art's duplicate schema and pipeline rows from the global
  Options screen while preserving its native values and persistence.
- Adds a `RENDER MODES` utility under the mod for the engine-owned `VOXEL` and
  `T-SHIFT` pipelines; all remaining settings stay sourced from the mod schema.
- Releases relative mouse capture and restores the visible cursor while a KRS
  screen covers the overworld; DramaticShape resumes capture on return.
- Does not alter or redistribute any DramaticShapeVoxelMod source file.

## 0.3.1 — Gen1Recomp 0.1.76

- Raises engine compatibility to Gen1Recomp 0.1.76.
- Preserves plug-and-play standard option/start-feature discovery and versioned exceptional adapters for the rebuilt Kanto UI.

# Changelog

## 0.3.2 — Consistent Kanto Ascendant menu art

- Adapts Kanto Ascendant 6.0.11's public Crystal animation exports to the Core
  Pokémon-art contract.
- Uses `KANTO CRYSTAL ART` consistently for KRS front sprites instead of
  mixing Ascendant's independent `DEX SPRITES` policy with other menu paths.
- Preserves shiny variants, external Kanto art ownership and the Gen-I
  fallback when Crystal art is explicitly disabled.
- Exposes Ascendant's own per-species Crystal frame timings to KRS menu
  presenters when `CRYSTAL ANIMATION` is enabled.

## 0.3.0 — Plug-and-play standard discovery

- Instruments the one real `ui.start_menu.items` hook call long enough to
  associate each added item with its Gen1Recomp hook owner.
- Moves discovered actions under `Mods → Installed Mods → [mod] → Features`
  without mod ids, labels, release tables or duplicate callback code.
- Reuses the generic Wide ListMenu/TextBox presenter and original callbacks.
- Keeps versioned adapters only for editorial grouping, exceptional states and
  behavior that the standard semantic contract cannot describe.

## 0.2.1 — Universal presentation contract

- Adds declarative adaptive-reader policy to the Ascendant adapter.
- Claims every Ascendant-owned Start-menu gateway, including dynamic utilities,
  and relocates it under the installed mod rather than matching one label.
- Ships the reusable compatibility protocol and validation matrix.

## 0.2.0 — Kanto Ascendant presentation adapter

- Adds a version-locked adapter for Kanto Ascendant 6.0.11.
- Groups Ascendant's native options inside its Installed Mods entry.
- Moves the Ascendant utility gateway out of the Main Menu and into the mod's
  Kanto Rework tree while preserving Ascendant's own callbacks and saves.
- Keeps all third-party logic in Ascendant; Compatibility owns only mapping.

## 0.1.1

- Re-bases every rule on the latest published GitHub release artifacts audited
  on 2026-08-09.
- Removes the obsolete Gen1Online 0.3.2 branch-source activation block and
  records the load-verified `v.3.4.1.1` release instead.
- Keeps the verified Kanto Ascendant / Trainer Rematch duplicate-ID diagnostic.
- Adds actionable advisories for the Useful Bag pocket overlap and the Quality
  of Life Easy Interactions / Kanto Field Moves overlap.

## 0.1.0

- Adds the first independent compatibility-policy package.
- Blocks the verified incomplete Gen1Online 0.3.2 entry source.
- Reports the Kanto Ascendant / Trainer Rematch duplicate manifest id.
- Contains no third-party monkey patches or copied implementation code.
