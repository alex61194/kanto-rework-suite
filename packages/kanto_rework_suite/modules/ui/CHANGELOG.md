## 0.8.58 — Off-battle Local scope, independent battle actions and full-viewport HUD movement

- Makes the visible GLOBAL/LOCAL segmented scope selector interactive in the Mods Live Editor and routes it through the canonical `setScope` path.
- Gives FIGHT, POKéMON, BAG and RUN independent persisted X/Y transforms while retaining the production command-card renderer, shared parent group transform and scale.
- Replaces the generic editor ±960/±540 clamp for non-trainer UI with bounds-derived full-viewport movement limits, preserving complete-component screen containment.
- Keeps trainer Intro/Battle/Post scene bounds explicit and separate.
- Adds/updates regressions for segmented scope input, independent action-card persistence/rendering and HUD movement beyond the Candidate.5 artificial walls.

## 0.8.57 — Battle Live Editor controls, trainer scene and semantic footers

- Unifies Live Editor keyboard/mouse/controller navigation through one focus/action model and keeps battle input modal while editing.
- Adds independent HUD scale/edge anchoring and production Action Menu + Move Selection/description live composition controls.
- Adds opponent trainer Intro/Battle/Post presentation, persistent Battle mode, scale/animation-speed editing and global KRS persistence.
- Resolves footer actions dynamically from current bindings and active input device.
- Fixes trainer preview phase selection and animated-atlas Canvas cache lifetime observed in Gen1Recomp 0.1.99 runtime testing.

## 0.8.56 — Live Editor input ownership correction

- Battle input now yields while `graphics_editor` is the top state, allowing the editor's keyboard/mouse layer to own interaction without disabling the live battle render underneath.
- Runtime diagnostic release metadata now matches the internal Suite module version.

## 0.8.55 — Live Mockup Editor battle-scene composition

- Restore direct live-battle access to the Graphics editor while retaining the Mods utility preview.
- Add independent Player/Opponent X/Y positioning, battle-only scale, direct drag, fine/coarse nudging, reset and session locks.
- Make the active Battle Background editable with aspect-preserving crop/zoom and X/Y framing offsets while transforming battle anchors consistently.
- Expose the real production Enemy HUD, Player HUD, Battle Action Menu and Move Selection/description composition as movable editor targets.
- Add a resizable responsive editor settings window and remove free numeric coordinate/scale entry in favor of sliders, drag, +/-/nudge and reset controls.
- Add explicit saved-vs-unsaved editing, Save, Discard, scene reset and dirty-exit protection.

## 0.8.54 — Post-test combat, input, sprite and Live Editor corrections

- Protect KRS battle Header/Footer from attack/status animation layers and remove battle START MENU.
- Make trainer identity responsive without ellipsis and map battle effects onto current rendered battler bounds.
- Fix Field Actions Fly integration, Map list-only keyboard/controller navigation, shared controller Back, and dynamic footer device labels.
- Enforce Front Sprite vs two-frame icon ownership, bound Mod Manager preview/info layout, and add generic KRS presentation for scripted ListMenus.
- Add Live Graphics focus states, real battle header preview, shared time-family Local settings, 1x→5x sizing, Small/Medium/Large presets, TAB X/Y grid, real live anchors and future Battle UI renderer contract.

## 0.8.53 — Map calibration, animated menu sizing, bumpers & live Graphics editor

- Full safe-viewport map pan with real image dimensions, explicit illustration calibration and keyboard/controller/mouse parity.
- Bounded menu Real Size with animated provider art across Party, Summary, Moves and PC.
- Rebindable L1/LB and R1/RB lateral navigation for Party hierarchy, Bag pockets, Options categories, Pokédex views and Mod Manager tabs.
- Runtime Graphics editor using the shared BattlePresenter pipeline, Global/Local overrides, live sprite drag/debug bounds, profiles and commit-on-interaction persistence.
- Filters editor Static/Animated choices to providers actually available for the selected side, adds direct numeric replacement entry, and bounds the animated-atlas GPU Canvas cache to a rolling 32-frame window.
- Adds contextual Mod Manager visual previews for Graphics/Visuals options and the active UI Theme.

## 0.8.52
- Restore Map/Fly as a complete Gen1Recomp TownMap view with independent per-location Fly capability and an always-present navigation sheet.
- Fix the missing map activeItemId presenter contract.
- Harden animated Party preview rendering so a visual-provider failure cannot blank the Party screen.
- Use the canonical player presentation-front component in Save and Main Menu.

## 0.8.51 — Animated KRS art, Nidoran glyphs and world phase UI

- Materializes KRS animated Pokémon atlases in battle, Pokédex/preview and Oak-intro contexts with nearest-neighbour frame extraction and a bounded frame cache.
- Animates supplied five-pose player battle strips in lockstep with Gen1Recomp's native trainer-introduction slide rather than a free-running wall clock.
- Fixes NIDORAN♀ / NIDORAN♂ by providing vector fallback glyphs through the shared KRS text renderer when packaged fonts lack U+2640/U+2642.
- Uses the Graphics Sunrise / Day / Sunset / Night phase in fullscreen world-time labels and battle-background selection.
- Keeps Party/PC/Save menu icon animation separate from battle Scale / Real Size.
- Raises the Oak-intro Pokémon presentation slightly so more of the body remains visible above the dialogue while allowing a small foot crop.

## 0.8.48 — Authored Pokémon Yellow Start artwork

- Integrates the supplied 2048×1152 Pokémon Yellow Start artwork as `assets/title/title_yellow.png`.
- Routes the Yellow ROM directly to that authored 16:9 plate, with the existing KRS NEW GAME / LOAD GAME / OPTIONS / EXIT GAME actions overlaid.
- Keeps the native Yellow title timeline alive for version-correct sequencing/audio while preventing the vanilla Yellow screen from being used as the primary Wide backdrop.
- Retains the engine-composed Yellow pieces only as a safety fallback if the authored asset cannot be loaded.

## 0.8.47 — Graphics ownership, rename states, shared Mart icons and Yellow KRS Start

- Consumes KRS Graphics before legacy compatibility art, and applies battle Scale/Real Size only to battle presentation contexts.
- Separates Rename Default/Hover/Focused/Selected/Pressed state ownership instead of moving keyboard focus on pointer hover.
- Reuses the Bag item-icon resolver in Poké Mart rows.
- Groups visible first-party KRS modules by manifest id prefix, so future KRS modules are included automatically.
- Stops using the full Yellow vanilla title plate as the KRS Start background and composes the Yellow title art inside the KRS Start surface.
- Intro Pokémon use front sprites; Red/Blue trainer presentation uses Graphics native 1:1 metadata and dialogue/screen clipping instead of fractional resampling.

## 0.8.46 — KRS naming, Mart confirmation, Graphics contexts and Yellow title timeline

- Converts the player-name and rival-name NamingScreen presentation to the KRS Wide shell while retaining Gen1Recomp's native glyph grid, presets, character limit and callbacks.
- Keeps physical keyboard text entry exclusive; Enter confirms, Backspace deletes, and Back from an empty direct-entry field returns to the native preset step.
- Converts the Poké Mart purchase/sale confirmation surface to KRS presentation while leaving native `ChoiceBox`, quantity and shop callbacks authoritative.
- Moves Party/PC Gen5 menu icons to the shared KRS Graphics registry, including stable two-frame animation, nearest-neighbour rendering and no theme tint or battle Real Size scaling.
- Reworks OakSpeech art resolution through `intro.scene`, `intro.trainer` and `intro.pokemon`; Red/Blue resolve Nidorino and Yellow resolves Pikachu with the same local layout/scale rules.
- Lowers trainer and intro Pokémon composition so the dialogue panel naturally masks the lower artwork, matching the supplied placement reference without stretching sprites.
- Fixes Yellow's Wide title freeze by advancing the native Yellow presentation timeline/blink while KRS remains the menu/input owner; no parallel native Start Menu is opened.
- Adds regression coverage for naming, shop confirmation, Graphics contexts, OakSpeech and Yellow title sequencing.

## 0.8.45 — Authored three-version intro pass and tutorial assets

- Replaces the Wide OakSpeech stage with the newly supplied 2048×1152 lab plate and full-resolution Professor Oak, Red, Blue/Gary and Nidorino artwork while preserving Gen1Recomp's complete OakSpeech state machine, naming callbacks, music, cries and save progression.
- Uses the authored Nidorino only when the engine demo species is NIDORINO; Yellow/non-Nidorino intros continue through the selected Pokémon-art provider.
- Mirrors the engine intro reveal/final shrink-and-fade presentation without changing its timing or callback ownership.
- Uses the newly supplied 128×128 Professor Oak back sprite for Yellow's scripted Pallet capture demo; Red/Blue keep the supplied Old Man sprite and every tutorial Pokémon remains engine/provider-owned.
- Keeps Red/Blue authored Start Screens and the version-correct native Yellow backdrop with KRS actions because no canonical 16:9 Yellow replacement artwork exists in the audited project resources.
- Resolves Red explicitly under Gen1Recomp 0.1.90; Gold and unknown/future versions keep their engine-owned backdrop instead of inheriting Red artwork.

## 0.8.44 — Version intros, Start Screens and capture tutorial presentation

- Adds KRS Start Screen support to Blue using the supplied authored artwork.
- Adds Yellow KRS Start Screen actions while retaining the official Yellow title backdrop until a dedicated 16:9 Yellow artwork is supplied.
- Replaces the official OakSpeech presentation on Wide with the supplied lab background, Professor Oak/rival assets, KRS dialogue chrome and the active Pokémon art provider.
- Skins scripted catching tutorials through KRS Battle and uses Old Man for Red/Blue and Professor Oak for Yellow via the engine `oakDemo` discriminator.
- Replaces the native Poké Mart BUY / SELL / QUIT root popup with the KRS shop surface while preserving native callbacks.

## 0.8.43
- KRS battle presentation no longer excludes scripted demo battles, so the capture-tutorial battle flow can render through the Wide battle skin instead of dropping back to the vanilla battle surface.

## 0.8.42 — Start-screen scope, PC focus cleanup, KRS level-up and locked header/content navigation

- Restricts third-party native menu actions to the title Start Screen; the in-game KRS Main Menu no longer mirrors Voxel/Dynamic-Cries/etc. actions.
- Removes the generic inner focus rail from PC Search and Sort By while preserving the authored PC outline and all four theme colors.
- Keeps Rare Candy level-up presentation inside KRS instead of exposing Gen1Recomp's 160×144 StatBox, while leaving the native StatBox in charge of timing and callbacks.
- Adds modern per-stat `+N` level-up deltas beside HP / Attack / Defense / Speed / Special values when a previous-level stat state can be established.
- Aligns Options and Mods with the validated Bag-style navigation ownership: header LEFT/RIGHT only while header-focused, clamped vertical content navigation after entry, and explicit Back to return to the header.

## 0.8.41 — PC extensions, strict 16:9 window contract and extension-menu recovery

- Removes PC box completion graphics, adds persistent-on-real-Save box names, a fifth Stored Pokémon row, search-aware disabled/no-match box states and untinted Normal/Shiny icon rendering.
- Adds Pokémon nickname editing from Summary through Gen1Recomp's native NamingScreen without direct disk writes.
- Locks Options/Mods LEFT/RIGHT navigation to the active content list once entered; header switching requires an explicit return to the header.
- Simplifies Capture Odds to available Ball, quantity and current capture chance without changing capture mechanics.
- Enforces the supported desktop 16:9 KRS presentation contract: windowed surfaces snap to 16:9 and unsupported fullscreen/borderless ratios use a reversible native-UI fallback.
- Fixes CLOSE returning to title artwork without action rows and preserves third-party title/start actions through Gen1Recomp's official extension hooks, including Voxel PRECACHE/CACHE when supplied.

## 0.8.40 — Corrective pass + Move Memory presentation

- Moves uses the confirmed Move Memory provider and allows out-of-battle active-slot replacement while keeping battle swaps disabled.
- Retro Bag/Mods focus is monochrome, selected header tabs remain rail-only, and Options/Mods detail panels no longer show stale row state while header focus owns navigation.
- PC restores confirmed remembered-move PP through the Core service and receives the current focus/selection corrections from this pass.

## 0.8.39 — Canonical Figma fidelity, PC session state and menu interaction states

- Re-aligns Party / Summary / Moves to the current canonical 1920×1080 Figma geometry and moves PARTY / SUMMARY / MOVES navigation back to the fullscreen header while preserving vertical navigation inside each view.
- Isolates Party menu icon sizing from battle Real Size / X2 / X3 presentation rules; the Party icon slot follows the Figma 96×96 wrapper with 64×64 visual content.
- Rebuilds the current PC redesign geometry: Search is centred over Stored Pokémon, Stored Pokémon is a 4×4 visible grid, Box Bank and context measurements follow the canonical mockup, and the exact Figma search icon is bundled.
- Makes PC search functional for Pokémon name, type and known move names; Sort By supports Pokédex / Type / Level and Pokédex order uses the canonical species `dex` field. Search and sort remain presentation-only.
- Removes UI-owned `writeSave()` calls from PC transfers/releases so box edits remain in the live session until the engine performs an explicit save.
- Re-aligns Bag Medicine to the current Item Ledger / Selected Item Context geometry, restores the canonical favorite star while preserving owned quantity, removes duplicated use/open copy from the detail panel, and bundles the exact current Figma item icons used by the authored Bag mockups.
- Centralizes fullscreen header Hover / Focused / Selected / Pressed / Disabled rendering and applies the actual per-theme Figma header accents, including monochrome Retro headers. Options, Bag, Mods and PC keep their independently authored content-focus colors.
- Adds regression coverage for PC non-persistence-before-save, dynamic search, real Pokédex sorting, Party / Summary / Moves rendering and current Figma layout tokens.

## 0.8.38 — Input arbitration, PC interactions and metadata fidelity

- Restores Bag back on A/Escape/right click, adds wheel handling to lists and native popups, and limits the battle Bag surface to use, pocket switching and back.
- Separates focused and selected header states in Options/Mods; opening starts in the header, Down enters content, and Back returns to the header before leaving.
- Groups runtime errors by mod with one row per complete error and a full-message reader.
- Implements PC search/sort, Party-style drag ghost/dashed pickup feedback, persistent source-box view after cross-box moves, pickup/drop SFX, move type icons and explicit Pokémon type names.
- Aligns right edges and removes decorative internal rails; normalizes Psychic aliases and uses the Perfect-DV star semantic outside Retro.
- Reads complete save/load metadata through Core 0.1.38 and removes the three UI-owned development toggles.

## 0.8.37 — Validated menu structural freeze pass 1

- Rebuilt Bag presentation around the validated Figma header-pocket hierarchy: horizontal pocket navigation, 924 px Item Ledger, 844 px Selected Item context, and no duplicated `ENTER — USE / OPEN` callout in the detail panel.
- Rebuilt Options around the validated fullscreen header categories and two-panel 1232/536 workspace.
- Rebuilt Mods around the validated fullscreen `MOD LIST / PROFILES / ERRORS` header and 1224/544 workspace.
- Rebuilt PC storage geometry to the validated 568 px Box Bank, 720 px four-column Stored Pokémon grid and 408 px context panel.
- Added a reusable fullscreen hierarchy-header renderer and updated header world-time presentation for the validated menu family.
- Preserved TM/HM move details and existing PC move/release functionality while changing layout.
- Added structural regression coverage for the four user-validated Figma families.

## 0.8.36 — Gen1Recomp 0.1.86 sandbox migration

- Loads every KRS UI module through Core-compatible sandbox source loading and resolves packaged images through `mod.assets:path()`.
- Replaces private cross-mod globals with public Core/Compatibility/Dev exports.
- Keeps the 72 canonical BattleBackGrounds, 36 calibrated ground-anchor profiles, shiny/provider art and bottom-centre frame grounding unchanged.
- Routes EXIT GAME through the engine-owned native TitleState action instead of calling blocked `love.event` from the mod sandbox.

## 0.8.35 — Native Voxel frames and frame-bottom grounding

- Voxel DEFAULT no longer fits sprites into the 380px KRS slot: one authored frame pixel now equals one logical battle pixel.
- Adds literal X0.25/X0.5/X2/X3 handling and continuous AUTO scaling supplied by Compatibility.
- AUTO is species/frame/side aware and gives player/back art a small perspective lift.
- Pokémon placement now anchors the bottom-centre of the complete authored frame/cell to the selected BattleBackGround circle centre instead of anchoring the last opaque sprite pixel.
- Non-Voxel providers keep the normal KRS battle slot but use the same frame-bottom circle grounding rule.

# Kanto Rework UI 0.8.35

## 0.8.34 — Per-background battle-circle grounding

- Replaced the single 630/790 + 1400/570 Pokémon ground pair with 36 calibrated scene profiles covering all 72 canonical battle backgrounds.
- Day/night/sunrise/sunset variants share geometry; Power Plant interior variants retain independent anchors.
- Added Compatibility-driven DEFAULT/X2/X3 Voxel presentation. X2/X3 bypass KRS slot normalization and preserve integer source-pixel upscale.
- Pokédex-height sizing now runs only when DEFAULT + POKÉDEX-SIZED POKÉMON is enabled.

## 0.8.33 — Voxel species-size calibration

- Adds a bounded Pokédex-height presentation multiplier for Battle Art Voxel sprites so short species no longer appear larger than much taller species solely because of atlas occupancy.
- The multiplier is deliberately non-linear and capped; it preserves playable composition for extreme heights while keeping the bottom of each sprite grounded on the authored battle-circle centre.
- Other sprite providers retain their existing scale unchanged.

## 0.8.32 — Overlay redesign, live provider art and battle grounding

- Replaced the old Area Catch List / Capture Odds body layouts with adaptive summary rails, responsive species/ball cards and sprite-aware scaling.
- Battle Pokémon frames now anchor by bottom-center to the visible battle-circle centers.
- Battle presentation consumes the provider's current live battler image instead of a detached preview frame.
- Bag UI copy now reflects vertical pocket-spine navigation in Bag, battle Bag, Shop Sell and PC item flows.

## 0.8.31 — Battle pointer, full-size art and responsive overlays

- Battle UI explicitly owns the mouse while passive overworld overlays do not, fixing the conflict with Voxel relative-camera capture.
- Cancels the previous battle-only 50% Pokémon sprite reduction and restores the 380×380 KRS battle slot.
- Retires Money, Play Time, Type Chart and Party overlays.
- Rebuilds Area Catch List and Capture Odds around width-and-height responsive card grids that retain every item instead of clipping or exposing `+N MORE`.
- Battle EXP fill now consumes the theme `exp` semantic color, fixing Retro black EXP instances.


- Imported the exact fixed-interior Figma scenes for Silph Co and the Team
  Rocket Hideout, bringing the canonical BattleBackGround set from 70 to 72.
- Routed all Silph Co and Rocket Hideout floors explicitly, with the Game
  Corner's Rocket encounter sharing the authored hideout scene.
- Replaced the last generic generated-background path with semantic canonical
  fallbacks for every Gen1Recomp 0.1.80 tileset and a safe time-aware road
  fallback for unknown mod-authored maps.
- Added regression coverage for all 72 files, 24 vanilla tilesets and 74 maps
  containing trainers or static battle objects.

# Kanto Rework UI 0.8.29

- Preserved KRS Options/menu presentation through fullscreen and windowed
  transitions by prioritizing the exact render-frame viewport over a
  transitioning live swapchain query.
- Declared visible modular overlays as pointer-owned surfaces in the overworld,
  allowing Core move/resize/collapse regions to receive the complete mouse
  sequence while Voxel free-camera capture is released.
- Added deterministic script-command speaker routing and an Oak's Lab event
  audit: starter prompts belong to Professor Oak, rival dialogue belongs to
  Blue, and receipt/system narration carries no speaker chip.
- Reduced Pokémon presentation inside battles to exactly 50%, preserving the
  existing 380 px placement slots, bottom anchors, effects and non-battle art.
- Added complete Gen I field notes for all 97 base item-name IDs across Bag,
  Shop and Player PC surfaces; provider-authored copy and TM/HM move data stay
  authoritative when available.
- Added the highlighted/selected Pokémon's four learned moves and live PP to
  the Box context panel beneath its sprite.
- Reworked native Link and Tournament presentation into responsive Wide
  interfaces for Cream, Graphite, Purple Night and Retro without replacing
  Gen1Recomp's network, handshake, trade or tournament state machines.

# Kanto Rework UI 0.8.28

- Added the complete 70-image Figma BattleBackGround set and a battle-stable
  resolver for authored maps, time of day and fixed-interior variants.
- Stabilized the starter DexEntry identity so animated third-party art providers
  no longer restart or fall back between redraws.
- Restored coloured Retro HP/EXP roles while retaining the explicit coloured
  type/status exception.
- Prevented Kanto Ascendant trainer-rank metadata and stale NPC hints from
  replacing the real rematch trainer name.
- Added TM/HM taught-move names, stats and ROM-aware descriptions to Bag details.
- Added theme-specific modular-overlay surfaces, rails, accents and typography.

# 0.8.27

- Replaced runtime-reconstructed Main Menu cards with 27 exact textless Figma
  component exports covering nine cards and all three interaction states.
- Bundled static Inter 400/500/600/700/900 and Pixelify Sans 400/500/700
  faces under their OFL licenses; Retro no longer uses the approximate raster
  atlas, and the three modern themes no longer depend on a missing font path.
- Locked the four product themes to their canonical Figma families and kept
  type/status semantics coloured in Retro per the requested exception.
- Replaced the Wide native starter Pokédex preview presentation with the KRS
  DATA frame and the selected Pokémon-art provider while leaving engine state,
  cry, dismissal and Oak-script continuation authoritative.

# 0.8.26

- Corrected Main Menu card state rendering against the canonical Figma component construction: Default is desaturated with black + cyan gradients; Hover is color with black + cyan gradients; Selected is color with the black gradient only.
- Replaced Main Menu badge placeholders with the native runtime trainer badge sheet/quads and live ownership state.
- Added Retro bitmap typography routing for distinct Regular, Medium and Bold faces with Figma-calibrated metrics and extended glyph coverage.
- Corrected SPECIAL move-category glyph to the diamond family instead of the Normal/circle glyph.
- Routed Main Menu and native Shop money through the KRS Pokédollar glyph instead of hard-coded currency text.
- Made text clipping UTF-8 safe so Nidoran ♀/♂ and other multibyte characters cannot be split during truncation.
- Product theme list remains Cream / Graphite / PurpleNight / Retro; Rouge is not exposed.

# 0.8.25 — Four-theme Figma integration

- Adds the player-selectable `CREAM`, `GRAPHITE`, `PURPLE NIGHT` and `RETRO` UI themes; Cream remains the default.
- Maps PurpleNight to the active Figma `Sombre` mode and deliberately excludes the technical `Rouge` mode from product theme selection.
- Applies theme tokens to shared surfaces, text, borders, HP/EXP roles, interaction colors, Options/Mods rails and all KRS presenters without recoloring true-color Pokémon/background assets.
- Adds `UI THEME` to Options → Graphics and persists it through the Core mod-runtime option service with live application.
- Updates Main Menu cards to the current Figma state grammar: grayscale Default, full-color Hover/Selected, cyan Hover for Cream/Graphite/PurpleNight, gray Retro Hover, yellow Selected and card elevation.
- Routes Retro typography through Gen1Recomp's built-in pixel face instead of redistributing a font file.
- Removes the remaining Cream-only Pokédex Oak modal fill and makes shared Party/type/status/overlay typography theme-aware.

# 0.8.24

- Makes Bag item/TM/HM target PartyMenu use the same two-column navigation graph as the canonical KRS Party screen for keyboard and controller.
- Audits Gen 1 NPC sprite gender metadata, including `SPRITE_SILPH_WORKER_F`, `_F/_M` sprite suffixes and the authored female sprite families.
- Migrates generated presentation identities to `character_names_v3` so previously mis-gendered assignments are regenerated while remaining unique and persistent.

## 0.8.23 — Wide battle prose + semantic identity hardening

- Keeps long move names on one line in the Fight list and centers POWER / ACCURACY label-value groups inside their Figma metric boxes.
- Reconstructs BattleState dialogue from the whole revealed semantic message instead of the rolling two-line Game Boy window, preventing move-learning text from being split across KRS boxes.
- Presents automatic/stay event TextBoxes with KRS chrome while preserving their native pagination, timeouts and cutscene callbacks.
- Repaginates manual MoveLearn/item-target TextBoxes before their first glyph and keeps direct post-MoveLearn battle text inside the KRS battle shell.
- Makes generated NPC/trainer personal names unique and persisted across sessions, class/gender-aware, and preserves canonical DAISY for Blue/Gary's sister; Oak Lab SCIENTIST object ids no longer get mistaken for PROFESSOR OAK.
- Adds pointer ownership for direct BattleState TextBox/ChoiceBox overlays so the mirrored KRS move-learning flow retains mouse/touch parity.

## 0.8.21 — Unified battle sprites, semantic identities + starter transition

- Resolves normal battle battlers through the same Compatibility-selected Pokémon sprite provider used by Party, Pokédex, PC and overlays, preventing transient BattleState fallback sprites from reappearing oversized.
- Hides both HP HUD cards during real move animations; hides the player HUD from move selection through the selected attack animation and restores it on cancel/completion.
- Places the command-phase player HUD exactly 8 px above FIGHT / POKÉMON / BAG / RUN.
- Centers the battle Party action popup over a darkened backdrop.
- Adds deterministic Kanto-appropriate presentation names for unnamed trainers/NPC dialogue and reuses the same trainer identity in battle headers.
- Releases Voxel relative mouse capture on Oak starter DexEntry and maps pointer/touch A/B exits without taking native starter-script ownership.
- Adds map-to-resource routing for Oak Lab, generic routes/cities and all eight Gen 1 Gyms while retaining safe packaged-background fallbacks.

## 0.8.20 — Native battle/item flow continuity + stable animation

- Keeps Voxel animated sprite size stable across changing frame silhouettes by scaling the authored animation cell into the canonical 380×380 slot.
- Captures Gen 1 move-learning TextBoxes/lists, healing target PartyMenu and Ether/PP move selection inside KRS instead of exposing vanilla surfaces.
- Fuses trainer replacement messaging into one responsive KRS dialogue with CHANGE / DON'T CHANGE actions and right-aligned choices.
- Reuses the canonical Party surface for native target/switch states and presents SWITCH / STATS / CANCEL in one centered Battle Action popup.
- Normalizes PSYCH_TYPE/PSYCHIC_TYPE to the centered PSYCHIC type token.
- Adds explicit save-slot confirmation, success/error acknowledgement and the engine Save sound on successful writes.
- Makes KRS HP/EXP interpolation respect the selected battle-speed multiplier while leaving animated sprite playback to Compatibility's real-time clock.

## 0.8.18 — Battle fidelity + semantic Mods manager

- Matches the canonical Figma battle header/footer, equal 380×380 battle sprite slots, move dock and stage-info modal.
- Smooths HP/EXP fills, exposes battle status icons, keeps trainer/attack presentation inside KRS, and replaces raw battle-text rendering with revealed glyph-safe text.
- Keeps level-up stat presentation inside the Kanto Journal shell.
- Pins the Kanto Rework Suite in Mods, classifies third-party mods semantically, and fixes long inline option scrolling for mouse and keyboard/controller navigation.

## 0.8.17 — Explicit KRS pointer-surface ownership

- Exposes exact KRS pointer ownership to compatibility adapters rather than
  treating every state above the overworld as a KRS menu.
- Restores the cursor when a keyboard/mouse session releases camera-owned
  relative mode, without making controller-only navigation show a pointer.
- Supports the Compatibility 0.3.4 Voxel 1ST/3RD event bridge.

## 0.8.16 — Menu pointer and responsive mod information

- Releases relative first/third-person mouse capture whenever an interactive KRS menu covers the overworld.
- Restores the cursor only for real mouse/pointer mode; controller navigation remains cursor-free.
- Reflows long mod descriptions before runtime state and permissions instead of drawing over them.
- Grows the cream information card responsively while preserving at least 8 px to the outer white frame.
- Adds a clipped internal viewport, visible scrollbar, wheel/drag input, and keyboard/controller detail scrolling for overflow.

## 0.8.15 — Main Menu rounded-frame hotfix

- Makes the Lua card frame authoritative for all Main Menu corner radii.
- Clips every raster illustration and disabled overlay through a 12 px rounded stencil.
- Prevents opaque export-canvas pixels from appearing behind rounded corners and elevation shadows.
- Preserves the existing Default, cyan Hover and yellow Selected states and four-direction navigation.

## 0.8.14 — Figma Main Menu

- Rebuilds the Wide Main Menu from the validated 1920×1080 image-card composition.
- Adds persistent yellow Selected and cyan Hover states with the shared Core elevation profile.
- Replaces linear navigation with spatial up/down/left/right traversal across Adventure, Connectivity and System rows.

## 0.8.13 — Moves long-name badge spacing

- Measures the active move name with the live Inter Bold font before placing
  the type and category badges.
- Keeps an adaptive 8–16 px gap after the move name and preserves the 16 px
  gap between badges.
- Covers the 27-character English maximum, including `MENACING MOONRAZE
  MAELSTROM` and `SOUL-STEALING 7-STAR STRIKE`, without badge overlap.
- Reduces only the active-move headline from 28 px to a minimum of 26 px when
  the measured name cannot otherwise fit; all previously validated geometry
  remains unchanged.

## 0.8.10 — Pokédex AREA habitat-list cleanup

- Removes the redundant field-records sentence from the `KNOWN HABITATS`
  panel so it cannot overlap the third and fourth habitat cards.
- Preserves the complete habitat list, selection focus, map interaction,
  footer, square outer panel and all validated Pokédex behavior.
- Adds a presenter-level regression check forbidding the removed sentence.

## 0.8.9 — Pokédex AREA edge closure

- Removes the outer corner radius from the full-height `KNOWN HABITATS`
  information card so the map cannot show through at the header or footer
  junctions.
- Preserves the rounded corners of the nested species and habitat cards, the
  interactive map viewport and all validated Pokédex behavior.
- Adds a presenter-level regression check requiring a zero-radius outer card.

## 0.8.8 — Pokédex AREA final alignment

- Separates the `ARROWS` key label from `HABITATS` in the AREA footer so the
  two strings cannot overlap at the canonical 1920×1080 viewport.
- Expands the `KNOWN HABITATS` information card to the complete 608×928 px
  right column between the shared header and footer, with regular 32 px inner
  margins; the interactive map viewport remains unchanged.
- Preserves the interactive map viewport, panning limits, habitat navigation,
  unified Ascendant sprite art and all validated Pokédex behavior.
- Adds presenter-level checks for the card position and footer prompt spacing.

## 0.8.7 — Pokédex AREA render recovery

- Restores the missing engine `Sprites` import used by the AREA habitat icon
  resolver.
- Prevents the AREA presenter from aborting after the map and city labels,
  which had left the right-hand habitat panel blank in 0.8.6.
- Preserves the 0.8.6 pointer-pan interaction, clipping, habitat navigation,
  Ascendant artwork contract and validated Pokédex layout.
- Adds a presenter-level regression test that must reach the right-hand AREA
  panel after resolving the selected species icon.

## 0.8.6 — Unified menu front sprites

- Routes Pokédex, Main Menu, Party/Summary/Moves, PC and adapted native views
  through one live Core Pokémon-art contract.
- Prevents species-only caches from mixing Gen-I and Kanto Ascendant artwork
  between screens or after an option change.
- Preserves true-color regions and shiny front variants.
- Plays Ascendant's Crystal frame timing in KRS menu portraits when its
  animation option is enabled, with a static-frame fallback.
- Restores the canonical female and male marks in NIDORAN♀ / NIDORAN♂ labels,
  backed by an embedded glyph fallback because the bundled Inter faces omit
  both symbols.
- Removes the redundant `ENTER · DATA` Pokédex footer action; `TAB · VIEWS`
  is now the only keyboard path between INDEX, DATA and AREA.
- Removes the inert `ENTER · FOCUS` prompt from AREA.
- Makes the AREA map draggable with the same pointer-pan behavior as the MAP
  shortcut, while habitat navigation keeps the selected marker visible.

## 0.8.5 — Figma-faithful Pokédex

- Rebuilds the Wide INDEX, DATA and AREA views from the canonical Figma
  frames with their exact 1920×1080 geometry, hierarchy, typography,
  interaction states, tabs, scrollbar, location register and footer prompts.
- Bundles the OFL-licensed Inter family and registers all five required
  weights through Core's shared typography service.
- Preserves the active `pokemon.sprite` true-color flag so Kanto Ascendant
  front art stays in full colour instead of being remapped to a DMG palette.
- Resolves AREA species icons through the live `pokemon.icon` hook.
- Adds the modal Professor Oak evaluation, official tier text and rating
  fanfare with keyboard, mouse and controller access.
- Preserves native/narrow fallbacks and runtime Seen/Caught/Unseen gating.

## 0.8.4 — Party recovery / cross-box storage

- Fixes the Party Summary and Moves renderer crash caused by endpoint-style
  separator calls being passed to the width-style line primitive.
- Keeps the KRS Party wrapper opaque so a presentation failure cannot expose
  the vanilla Party screen underneath it.
- Restores move power, accuracy and Gen 1 physical/special/status categories.
- Adds mouse drag/drop plus keyboard/controller pick-up and placement between
  any PC boxes, with visible selected and destination states.
- Uses the Figma Resources grass, forest, cave and water battle backgrounds.
- Resolves the focused Party Pokémon in the Main Menu through the live engine
  sprite hook, so Kanto Ascendant art is used when its art option is active.
- Restores fine separators, selection rails and box occupancy tracks from the
  current Figma Menu Prototype.

## 0.8.3 — Figma reconciliation / inverse hierarchy

- Treats the AI-generated Figma export as an implementation reference only and reconciles it against canonical mockups, validated project decisions and live Gen1Recomp behavior.
- Restores the validated inverse Bag Pocket Spine with cream Selected and turquoise Focused states.
- Uses the canonical `#F2C229` Options/Mods selected token independently from Pokémon Electric type color.
- Aligns Battle command cards and move-row inversion with the current Figma Commands/Fight frames.
- Refines Pokédex DATA hierarchy and removes unsupported Unicode status/location glyphs from runtime text.
- Keeps Save default cards inverse and the focused card on the Figma elevated cream surface.
- Restores trainer portraits and active-Party icons inside Save/Load cards using engine-owned sprite resolvers.
- Replaces unsupported arrow glyphs in Wide runtime footers with explicit `UP/DOWN` and `LEFT/RIGHT` labels.

## 0.8.2 — Figma parity / Wide input completion

- Restores explicit mouse-wheel navigation without reintroducing hover-as-selection.
- Adds locked Options edit mode, empty-slot Save activation, draggable Bag/PC scrolling and PC drag-and-drop.
- Aligns Pokédex DATA/AREA, Bag, PC and Battle Wide layouts with the canonical Figma mockups.
- Battle now uses a horizontal command row, vertical move list with selected-move information, KRS-scaled 380×380 active sprites, complete player/team footer, KRS battle Party routing and KRS presentation during non-menu battle phases.
- Keeps KRS-owned Wide descendants from falling back to native Party/Bag/status presentation where an adapter exists.

## 0.8.1 — Wide controller ownership / input integrity

- Pokédex row hover is visual-only; pointer movement no longer commits a different species or view state.
- Save-slot hover is visual-only and no longer changes the committed slot focus.
- Save cards now map deterministically to engine ids `slot1`–`slot4`; saving an empty card preserves the card number instead of allocating the first free registry position.
- Loading a slot no longer pops the state stack after Gen1Recomp `restoreSave()` has already rebuilt the overworld, preventing the empty-stack softlock.
- Added `pc_storage` to the KRS menu input layer so the custom PC storage screen receives pointer/key routing.
- Wide native semantic menus now use KRS-owned navigation for handled ListMenu/Menu/QuantityBox/ChoiceBox states while preserving native callbacks, persistence and safe fallback.
- Native list hover no longer mutates the engine cursor; click/confirm commits selection.
- Summary stat tabs no longer switch mode on hover; click remains the committing action.
- PC storage cross-transfers now match Gen1Recomp 0.1.77 semantics: box Pokémon regain party stats, party deposits preserve Yellow happiness handling, and changing boxes plays the engine Save SFX.
- Pokédex delegates to the native screen outside supported Wide layouts instead of leaving a blank custom state.

## 0.8.0 — Menu rework / Gen1Recomp 0.1.76

- Rebuilds Wide presentation against the current Figma `Menu rework` source of truth.
- Adds native 0.1.76 Save/Load slots, custom Wide Pokédex INDEX/DATA/AREA, Party dossier/workspace views, Bag register popup, transaction Shop surfaces and direct Bill’s PC storage.
- Updates Options/Controls and Mods dashboard presentation.
- Adds battle command/move presentation, last-ball context and a TAB Battle Info overlay while the native BattleState retains turn ownership.
- Keeps native/narrow fallbacks and existing compatibility adapters.

## 0.7.13

- Remaps KRS mirrored two-choice dialogue navigation from the native vertical Up/Down model to Left/Right, matching the horizontal Figma choice layout while preserving native A/B confirmation, hold frames, sound and callbacks.
- Makes Up/Down inert only while a mirrored KRS horizontal YES/NO choice is active; native ChoiceBox behavior outside KRS dialogue remains unchanged.
- Extracts explicit ROM speaker prefixes such as `KOGA:` into the speaker chip and removes the prefix from the message before Wide repagination.
- Protects sign content from speaker extraction so labels such as `TRAINER TIPS:` remain part of the sign text.
- Adds trainer-class speaker hints for NPC interactions and recognizes the Poké Mart greeting as `CLERK`, while retaining the existing `NURSE JOY` mapping.
- Delays Wide dialogue preparation from `screen.pushed` to the first TextBox draw so `world.interacted` can provide authoritative NPC/sign context before repagination.
- Validated with the supplied Gen1Recomp 0.1.75 / LÖVE 11.5 Linux runtime on real Nurse Joy, Fuchsia Gym Koga and Poké Mart confirmation flows.

## 0.7.12

- Aligns the runtime overworld dialogue presenter with the validated minimal Figma family: optional speaker, message, then compact choices.
- Removes choice ordinals, the full-width choice treatment, divider chrome and the large response container from runtime confirmations.
- Uses 180×64 minimum confirmation choices with 10 px spacing; labels may grow up to 320 px without consuming the full 1056 px dialogue width.
- Adds reliable speaker chips only for contexts with confirmed identity: Nurse Joy dialogue and Poké Mart clerk footer. Unknown/sign dialogue remains unlabeled rather than inventing a speaker.
- Retains native TextBox/ChoiceBox/ListMenu update, input, timing and callback ownership and the 0.7.10 graphics-state isolation.
- Validated on the supplied Gen1Recomp 0.1.75 Linux/LÖVE 11.5 runtime before packaging.

## 0.7.10

- Fixes the Linux-reproduced overworld dialogue blackout by isolating the KRS
  HUD draw with `love.graphics.push("all")` / `pop()`. The previous dialogue
  draw leaked the dark text colour into the next overworld frame.
- Removes every dialogue-path clear of the shared Gen1Recomp UI canvas and
  suppresses only the eligible native `TextBox:draw`; native update, input,
  sound, timing and callbacks remain engine-owned.
- Reconstructs eligible manual overworld TextBox content as Wide prose before
  typing starts, then repaginates it against the real 1056 px KRS text width.
  Legacy Game Boy NL/CONT/page layout boundaries no longer force narrow pauses.
- Keeps a maximum of three KRS text lines per page and retains native final/page
  confirmation semantics after repagination.
- Removes the runtime Continue icon/cue; no width is reserved for it.
- Leaves automatic, stay-owned and choice TextBoxes on the native local fallback.
- Validated against the supplied Gen1Recomp 0.1.75 Linux AppImage and supplied
  Fuchsia City save under LÖVE 11.5/Xvfb.

## 0.7.9

# 0.7.7

- Uses Core 0.1.29's verified restart request instead of accepting a silent
  `restartWithMods()` return as success.
- Shows `GAME SAVED · RESTART REQUESTED` only after a restart event has
  actually been queued.

# 0.7.6

- Displays provenance-resolved third-party Start Menu actions automatically
  under the owning Installed Mods card instead of the Kanto Main Menu.
- Reuses the adaptive Wide reader for automatically discovered standard
  ListMenu/TextBox trees.
- States explicitly that `Restart Now` saves progress before restarting.
- Works with Core's one-shot game/slot resume path so the restart returns to
  the saved game instead of the launcher on supported desktop platforms.

# 0.7.5

- Reflows narrow TextBox pages into one ordered Wide document instead of
  preserving the vanilla two-line/page reading cadence.
- Adds bounded document scrolling, visible progress, mouse-wheel and draggable
  scrollbar support, screen jumps and deferred final choices.
- Preserves source-page order, default-no choices, callbacks and local native
  fallback for timed or presentation-specific states.

# 0.7.4

- Presents adapter-owned third-party features under the installed mod instead
  of adding parallel Main Menu buttons.
- Adds a reusable Wide presenter for external ListMenu/TextBox trees while
  preserving the source mod's callbacks, option values and persistence.
- Shows Kanto Ascendant 6.0.11 settings inline in grouped sections and routes
  its utility hub through Mods for keyboard, controller, mouse and touch.

# 0.7.3

- Keeps the Wide Kanto Start Menu active when another mod adds a valid native
  Start-menu action.
- Displays those actions in the System row and preserves keyboard, controller,
  mouse and touch activation through the original callback.

# 0.7.2

- Displays compatibility diagnostics and capability claims in the Mods model.
- Replaces the ambiguous restart prompt with explicit Restart Now, Later and
  Discard Changes actions.
- Uses Core's guarded restart path so saving/restarting is refused while the
  overworld state is moving or otherwise unsafe.
- Declares the Kanto full UI shell and Party UI as cooperative capabilities.

# 0.7.1

- Clips every dynamic menu list to its own panel instead of allowing rows to render or receive clicks through headers and footers.
- Adds focus-following, mouse-wheel and draggable 44 px-hit-area scrollbars to Options categories/settings and the compatibility Controls screen.
- Extends the existing Mods scrollbar to Profiles and Errors as well as Installed Mods.
- Adds overflow scrolling to mod-authored Map/Fly destinations and Field Actions.
- Replaces the eight-row Learned Moves cutoff with an accessible scrolling window that follows keyboard/controller focus and supports mouse/touch input.

# 0.7.0

- Makes overlay headers, resize corners, collapse controls and reduced tabs directly interactive whenever F8 shows the overlay layer.
- Restricts F9 to Overworld/Battle/Both/None context selection; F9 no longer moves, resizes or collapses widgets.
- Temporarily previews collapsed widgets as context cards in F9 without changing their persisted collapsed state.
- Keeps collapsed tabs above expanded windows and temporarily shifts a tab to the nearest free slot on its preferred edge when a window would cover it.
- Returns every temporarily shifted tab to its exact preferred position as soon as the blocking window disappears, without rewriting `TabEdge` or `TabPosition`.
- Raises collapse and resize hit targets to a minimum of 44×44 pixels and adds a shape outline to the selected context choice.
- Adds configurable direct F8 keyboard/controller layout adjustment (`F6` / DualSense Touchpad by default): directions move, Confirm toggles Move/Resize, Select changes widget, Start collapses/restores and Cancel exits.

# 0.6.9

- Makes every collapsed overlay tab draggable during normal gameplay, without F9.
- Keeps click/touch restoration distinct from dragging through a movement threshold.
- Preserves the expanded position and dimensions while storing the tab's edge and along-edge position independently.
- Reuses the moved tab placement after restore and every later collapse.
- Supports collapsed-tab movement with keyboard and controller in F9.

# 0.6.8

- Reorders the Map/Fly destination list as Pallet, Viridian, Pewter, Cerulean, Vermilion, Lavender, Celadon, Saffron, Fuchsia, Cinnabar and Indigo Plateau.
- Makes Up/Down follow the previous/next row in that displayed list for both keyboard and controller, independent of POI coordinates.
- Retains unknown or mod-authored destinations after the curated Kanto sequence in stable source order.

# 0.6.7

- Renders the canonical Kanto map full-bleed beneath a full-height cream Fly destination sheet, eliminating the black right-side gutters.
- Repositions and compacts map labels, adding short POI anchor lines only where labels are displaced.
- Adds explicit `CURRENT`, `AVAILABLE` and `LOCKED` row states so unavailable Fly destinations are not communicated by color alone.
- Separates the full map drawing viewport from the uncovered interaction safe area, keeping selected POIs visible and drag gestures out of the destination sheet.

# 0.6.6

- Shows a compact minimize control in every expanded overlay header during normal gameplay as well as F9 editing.
- Collapses with mouse/touch and restores by activating the visible edge tab, without opening F9.
- Adds configurable `COLLAPSE / RESTORE OVERLAY` input (`F12` / left-stick click by default) for the last targeted visible overlay.

# 0.6.5

- Adds a per-widget `COLLAPSE` control in F9 edit mode.
- Docks collapsed widgets to the nearest left, right, top or bottom edge while preserving their expanded position and free-aspect size.
- Restores edge tabs by mouse/touch click, or with Confirm while the tab is focused in F9; Start toggles collapse for keyboard/controller editing.
- Uses the native generated Poké Ball asset plus a short text identifier on every persistent edge tab.
- Brings the focused F9 widget to the front and prevents narrow context labels from wrapping by switching to a 2×2 control grid.
- Replaces silent clipping in Party, Wild Encounters and Capture Odds with a visible overflow count.
- Adapts the Generation 1 type matrix to compact aspect ratios without letting the grid extend beyond its box.

# 0.6.4

- Makes `LOAD GAME` the default title action whenever an active save exists; `NEW GAME` remains the fallback without a save.
- Keeps the complete curated Kanto town set on the map independently from the filtered Fly destination list.
- Removes the player marker circle and draws the live overworld sprite at exact 2× on the top map layer.
- Makes corner dragging update visible width and height together and reflows dense overlay content against both available axes.

# 0.6.3

- Removes the Map arrow entirely; selected destinations now rely only on the established blue focused-box border.
- Replaces proportional widget scaling with independent width/height resizing and breakpoint-based content reflow.
- Moves individual widget visibility out of mod options and into each F9 edit window as Overworld/Battle/Both/None.
- Keeps every widget configurable in edit mode even when its runtime context is None or its live data is unavailable.
- Preserves F8 as the global switch for the complete configured overlay set.

# 0.6.2

- Replaced the circular Map selection marker with a directional high-contrast adventure cursor.
- Routes every mouse, keyboard and controller Fly confirmation through Core's HM02 + Thunder Badge + outdoor progression gate.
- Adds a bottom-right mouse resize handle to every overlay while F9 edit mode is active.
- Persists each widget's scale and recalculates its layout on resize/window changes with widget-specific readability floors.

# 0.6.1

- Removed the title-screen container and all title tint/bars; the four startup actions now float independently over the artwork.
- Removed the Map header/footer bars, narrowed the Fly panel and rows, and removed decorative list icons.
- Added mouse/touch panning for the full-color Map while keeping POIs, selection and the live 16×16 player sprite interactive.
- Added `DEVELOPMENT` and `OVERLAYS` subcategories inside the UI mod options.
- Added responsive overlay scale from 50–100%, configurable through the menu and the remappable `F11` action.
- Added Paper and semi-transparent Glass overlay surfaces.

# 0.6.0

- Replaced Pokémon Red's Wide title with the canonical Figma artwork and a four-action popup; `LOAD GAME` restores directly without the native save recap or a slot picker.
- Replaced the generated monochrome Town Map presentation with the canonical Figma Kanto map while preserving runtime Fly POIs and the native player sprite layer.
- Removed the Current Location overlay and the black accent rail.
- Expanded Party with native icons, type glyphs, HP bars and numeric HP.
- Added contextual Wild Encounters, Generation 1 Type Chart and per-Ball Capture Odds overlays.
- Extended overlay move/lock input to battle and preserved the Wide fallback boundary.

# 0.5.0

- Added the configurable `MAP` action and a themed Map/Fly screen with shared mouse, keyboard and controller navigation.
- Replaced the text player marker with the live overworld sprite drawn at native `16×16`, without embedding Red in the design file or scaling the runtime sprite.
- Added a label-only contextual Field Actions popup with shared multi-input focus and no action descriptions.
- Replaced the Companion-style panel with independent Player, Party, Location and Session overlays, each exposed as an ON/OFF mod option.
- Added persisted mouse dragging and keyboard/D-pad movement for every overlay, with `F8` visibility and `F9` move/lock mode.
- Kept ROM-specific title screens as planned, non-Legacy resources for later runtime selection.

# 0.4.13

- Makes the Mods information panel context-sensitive: a mod row shows the manifest/card summary, while an inline option row shows that option's label, current value and schema description.
- Preserves the parent mod's runtime state, compatibility and declared permissions while an option is focused.
- Applies the same detail source for keyboard, controller, mouse hover and touch selection.

# 0.4.12

- Routes canonical Standard semantic tokens into Core 0.1.13's full-frame accessibility shader, preventing double correction while covering Wide menus, party screens, overlays and imported UI assets.
- Color accessibility is no longer restricted to the engine's Advanced color mode.

# 0.4.11

- Replaced the complete Type and Status glyph pipeline with direct transparent SVG exports from the validated Figma glyph-only component families.
- Added all 18 canonical type SVG sources (`20×20`) and all 7 canonical status SVG sources (`32×32`).
- Added generated 1x/2x/3x/4x runtime rasters with preserved antialiasing and white RGB in transparent texels for halo-safe linear filtering.
- Added `generated/glyph_manifest.json` and a centralized `generated/assets.lua` registry for both type and status glyphs.
- Added `TypeChip` from the validated `148×36` Figma Type Token and corrected compact Type Icon geometry to `32×32` container / `20×20` canonical glyph.
- Rebuilt Status Icon/Token on the current Figma source nodes; Badly Poisoned now uses the canonical vector exclamation and only reconstructs its semantic 12×12 marker container in Lua.
- Removed old status raster names (`poison`, `toxic`, `burn`, `paralyze`, `sleep`, `freeze`, `faint`) from the runtime package.
- Replaced old type rasters in-place and added a 4x density tier; no profile-specific geometry assets are generated.
- Updated Standard semantic type/status colors to the current Figma default tokens while preserving the existing Protanopia, Deuteranopia and Tritanopia runtime profiles.
- Routed Party Active detail, Party Cards, Summary and Moves type/status presentation through the shared components.
- Added opt-in `glyph_test_board` runtime QA overlay and reproducible static validation/evidence tools.
- No `kanto_rework_core` or `kanto_rework_gameplay` change is required by this migration.

# 0.4.10

- Rebuilt STATUS presentation from the canonical Figma `KRS / Feedback / Status Token` component family.
- Removed the opaque black matte introduced by the previous raster draft assets.
- Replaced procedural / approximate glyphs with white-alpha masks derived from the then-current Figma atomic status icons.
- Added a shared `StatusBadge` runtime architecture with Full (188x40) and Compact (32x32) usage.
- Split semantic status color roles into outline / icon / marker and routed them through the global Palette Resolver.
- Added status palette variants for Standard, Protanopia, Deuteranopia and Tritanopia without changing glyph geometry.
- Preserved all Party, Controls, Mods, input, routing and gameplay behavior from 0.4.9.

# 0.4.9

- Fixed StatusToken bootstrap dependency injection.
# 0.8.11 — Pokémon menu fidelity pass

- Rebuilt Party composition against the validated Figma frame: team-formation hierarchy, native party-ball row, card spacing, compact animated art and complete selected-Pokémon ledger.
- Migrated Party, Summary and Moves to the shared Inter typography registry with explicit production weights.
- Rebuilt Summary stat tabs, DV formatting, perfect-DV label, Stat Experience caps and future-mod badges while retaining the runtime Active Moves panel.
- Rebuilt Moves hierarchy and corrected Physical / Special / Status category presentation while retaining active moves and the tracked learned-move workflow.
- Preserved keyboard, mouse, controller and touch navigation, move/party reordering, animated Ascendant art and Wide-only fallback behavior.

# 0.8.12 — Pokémon menu correction pass

- Restores the previous integer-scaled front-sprite size in Party, Summary and Moves.
- Keeps Team Position and Experience labels and values inside the Party detail card.
- Embeds the canonical Figma party-ball states: Normal, Status and KO.
- Removes obsolete future labels for IV/EV and learned moves.
- Keeps Summary stat values inside the dossier table.
- Widens move-category badges and resolves learned-move details from hover, focus or the active move.
# 0.8.17

- Release relative first/third-person mouse capture whenever an interactive KRS menu covers the overworld.
- Restore the cursor only for real mouse/pointer mode; controller navigation remains cursor-free.
- Reflow long mod descriptions before runtime state and permissions instead of drawing over them.
- Grow the cream information card responsively while preserving at least 8 px to the outer white frame.
- Add a clipped internal viewport, visible scrollbar, wheel/drag input, and keyboard/controller detail scrolling for overflow.
