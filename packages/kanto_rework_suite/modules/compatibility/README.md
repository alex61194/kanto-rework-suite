# Kanto Rework Compatibility 0.4.14

## 0.4.14 — Gen1Recomp 0.1.86 sandbox baseline

- Requires Core 0.1.37+ and uses `mod.find(...).exports` for all intentional KRS cross-mod communication.
- Gen1Recomp's `input.pointer` hook owns physical mouse/touch delivery; Compatibility no longer replaces `love.mousemoved`, `love.mousepressed`, `love.mousereleased` or `love.mouse.setVisible`.
- An `input.step` maintenance pass releases Voxel relative capture only while a KRS menu, interactive overlay, battle UI or Dev surface owns the pointer; passive first/third-person world look remains Voxel-owned.
- Shiny atlas selection, native-frame scaling controls and provider arbitration remain Compatibility-owned and third-party source stays untouched.

## 0.4.13 — Native Voxel scaling owned by Compatibility

- Moves the KRS sprite scaling controls from the Battle Art Voxel Fork card to the Kanto Rework Compatibility card.
- `UPSCALE`: `DEFAULT` (strict native x1), `X0.25`, `X0.5`, `X2`, `X3`, `AUTO`. Fixed modes are literal authored-frame pixel multipliers.
- `POKÉMON REAL SIZE`: `NO`, `YES`, `AUTO`; it is consumed only by `UPSCALE=AUTO`.
- AUTO calculates a continuous multiplier from the current Pokémon's native frame dimensions, Pokédex height policy and front/back perspective.
- Explicit shiny Pokémon resolve the generation-specific Voxel shiny dataset before the normal live battler image.


## 0.4.12 — Voxel scale policy + authoritative shiny dataset

- Adds KRS-owned BATTLE ART controls under Battle Art Voxel Fork: UPSCALE = DEFAULT / X2 / X3 and POKÉDEX-SIZED POKÉMON (DEFAULT mode only).
- DEFAULT keeps KRS slot fitting; X2/X3 bypass fit normalization and preserve exact integer authored-pixel scaling.
- Gen5 shiny resolution now reads the fork's generated `animated_battle_sprites_gen5_shiny` dataset directly, with the previous path rewrite only as a compatibility fallback.
- Exposes the resulting presentation policy to Kanto Rework UI without modifying Battle Art Voxel Fork.

## 0.4.11 — Explicit Gen5 shiny atlas routing

- When a Pokémon is explicitly marked `shiny=true`, KRS now resolves the Voxel Gen5 animated front from `assets/battle/front-animated/gen5/shiny` before accepting a normal live battler frame.
- Reuses Voxel's own atlas geometry, timings, decoder and frame anchors; no third-party file or option is modified.
- This covers debug/mod-authored shinies whose explicit shiny state can differ from Voxel's DV-derived shiny rule.

## 0.4.10 — Live Voxel animation ownership

- Stops re-applying Battle Art on every KRS render frame, which restarted animated atlases at frame one.
- Re-applies only when provider settings or the live battler changes, preserving party switches and shiny/provider changes.
- KRS battle surfaces now consume the real Voxel battler sprite frame; menu/overlay previews retain an isolated animation timeline.

## 0.4.9 — Voxel camera/pointer arbitration

- Passive KRS F8 overlays no longer release Voxel relative capture, so first/third-person mouse-look remains active.
- Explicit overlay interaction, KRS battle UI and the Dev overlay still take temporary pointer ownership and restore the system cursor.

## 0.4.8 Voxel cursor ownership across overlays and video changes

- Treats KRS modular overlays as interactive pointer surfaces even when the
  overworld remains the active stack state.
- Re-acquires `love.mouse.setVisible` if fullscreen/windowed recreation or a
  later mod replaces that function independently from relative-mode capture.
- Uses the physical mouse callback as immediate pointer intent before Core's
  device snapshot is updated, then restores controller-only cursor policy.
- Applies the same policy to the 1.7.9 adapter and the live 1.8.x family
  adapter without editing Battle Art Voxel Fork itself.

## 0.4.7 Voxel pointer and shiny continuity

- Prevents late Voxel `setVisible(false)` writes from hiding the cursor while
  a mouse/pointer-owned KRS menu covers a 1ST/3RD-person overworld; controller
  navigation and uncovered world capture keep their native cursor policy.
- Reasserts cursor visibility after every routed menu pointer phase and restores
  the original LOVE callback functions when the adapter unloads.
- Passes a read-only projection of the real Pokémon record, including shiny and
  DV data, into Voxel's live BattleArt resolver. Normal and shiny Pokémon of the
  same species now use distinct preview cache identities on KRS surfaces.

Targets Gen1Recomp >=0.1.86 <0.2.0. This package contains automatic standard-menu discovery, capability/contract-driven provider detection, activation guards and actionable diagnostics for third-party Gen1Recomp mods.

It does not copy third-party source code and does not install persistent
monkey patches over external mods. Shared provider arbitration lives in Kanto
Rework Core; this package can be updated independently when supported mods
publish new releases.

## P0 rules (release audit 2026-08-09)

- Treats the published Gen1Online Game Corner `v.3.4.1.1` ZIP (manifest
  `gen1online-gamecorner` `0.3.4.1`) as the current player build. It is not
  blocked; its entry loads successfully with the Kanto packages.
- Detects the duplicate `trainer_rematch` loader id used by Kanto Ascendant
  `6.0.11` and Trainer Rematch `0.4.4` into an explicit critical diagnostic.
- Warns when Useful Bag `2.4.1` and Kanto Gameplay both own Bag organization.
- Warns when Quality of Life `1.2.7` Easy Interactions and Kanto contextual
  Field Moves can expose duplicate field actions.

## Plug-and-play coverage

- Every installed mod is listed from the native manager model.
- Standard option schemas are rendered inline automatically.
- Active actions added through `ui.start_menu.items` are attributed to their
  hook owner and moved under that mod's `Features` group.
- ListMenu and TextBox descendants use the adaptive Wide presenter.
- No mod-specific id or label is required for this automatic path.

## Presentation adapters

- Kanto Ascendant family: the latest audited release is `6.0.11`, but activation is based on repository/id identity plus the live `ascendantMenu` / `crystalAnimation` export contracts. Compatible version-only updates keep working without a KRS release; a missing contract disables only the affected seam. Its native option schema remains under the installed mod and Ascendant remains authoritative for values, callbacks, progression and persistence.
- Battle Art Voxel Fork `1.7.9` legacy plus current/future contract-compatible releases: their native schema stays under Installed Mods,
  its `VOXEL` and `T-SHIFT` pipeline controls are exposed through `RENDER
  MODES`, its duplicate global Options rows are removed, and relative mouse
  capture is released only while a KRS pointer surface owns the screen. Gen1Recomp
  0.1.86's public `input.pointer` seam remains the sole physical pointer ingress;
  Compatibility does not replace Voxel or LÖVE mouse callbacks. While Voxel
  FreeMove owns overworld walking, Compatibility also routes blocked
  camera-relative pushes to Gameplay's registered automatic Cut/Surf actions.
  The DramaticShape archive and source remain untouched.

The reusable adapter contract, adaptive-reader rules, fallback boundaries and
acceptance matrix are defined in `docs/UNIVERSAL_COMPATIBILITY_PROTOCOL.md`.

## 0.4.1 visual/audio ownership

`POKéMON SPRITES` is an exclusive Compatibility capability shared by KRS battle, Party, Pokédex, PC and other KRS Pokémon-art surfaces. Audited providers are Gen1Recomp, Battle Art Voxel Fork 1.8.3 and Kanto Ascendant 6.0.11. The Gen 1 choice bypasses third-party live sprite hooks for KRS presentation, so the selector is truthful.

SFX Music Replacement 2.0.0 owns music/general SFX. Dynamic Cries 1.4.3 owns the Pokémon cry registry. They are classified separately; a conflict selector is created only when two active mods claim the same capability.

## 0.4.3 global Options ownership

Standard mod options and proven custom duplicates remain under their owning MODS card rather than leaking into the global Options screen. This includes custom rows such as SFXMusicReplacementMod SOUNDTRACK / SOUND EFFECTS / STEREO SOUND. Equivalent mod-owned render-pipeline controls are also hidden globally when the owning mod already exposes the same setting through its schema. Native engine settings remain in Options.



## 0.4.6 contract-family ownership

Third-party release numbers are audit metadata, not activation gates. Kanto Ascendant, SFX Music Replacement and Dynamic Cries are enabled only when their live contracts are actually present. The manifest no longer caps Ascendant or SFX to one minor line.

Future mods that own the public `pokemon.sprite` hook are discovered from Gen1Recomp's runtime hook provenance. If selected, KRS executes only that owner's hook chain against an immutable Gen1 terminal fallback; no unselected sprite mod can re-enter implicitly. Stable provider ids preserve capability preferences across compatible version updates.

Known audio families are contract-gated at `game.ready`: SFX Music Replacement requires its standard options plus `music.select`/SFX registry ownership; Dynamic Cries requires the audited repository identity plus live cry-registry ownership. A version change alone neither enables nor disables a provider.

## 0.4.5 strict sprite ownership

`POKéMON SPRITES` is an exclusive capability. Once Compatibility selects Voxel, Kanto Ascendant, or Gen 1, other sprite providers are not permitted to re-enter through the engine fallback hook chain. If the selected provider intentionally resolves to ROM/missing art, KRS uses the immutable Gen 1 species path as that provider's terminal fallback.

## 0.4.4 Voxel sprite provider

When `POKéMON SPRITES` selects Battle Art Voxel, KRS now asks the live Voxel BattleArt/AnimatedBattleArt runtime to resolve the selected image before using its compatibility decoder. This keeps battle, Party, Pokédex, PC and other KRS surfaces aligned with Voxel 1.8.4 collection/shiny/species-alias rules without modifying Voxel.
