# Item pocket catalog — Gameplay 0.2.5

The pocket layer is derived at runtime. It does not migrate or duplicate the
flat `save.inventory` / `save.bagOrder` representation.

## Medicine

`POTION`, `SUPER_POTION`, `HYPER_POTION`, `MAX_POTION`, `FULL_RESTORE`,
`ANTIDOTE`, `BURN_HEAL`, `ICE_HEAL`, `AWAKENING`, `PARLYZ_HEAL`, `FULL_HEAL`,
`REVIVE`, `MAX_REVIVE`, `FRESH_WATER`, `SODA_POP`, `LEMONADE`, `HP_UP`,
`PROTEIN`, `IRON`, `CARBOS`, `CALCIUM`, `RARE_CANDY`, `PP_UP`, `ETHER`,
`MAX_ETHER`, `ELIXER`, `MAX_ELIXER`.

## Poké Balls

`MASTER_BALL`, `ULTRA_BALL`, `GREAT_BALL`, `POKE_BALL`, `SAFARI_BALL`.

## Battle Items

`X_ACCURACY`, `GUARD_SPEC`, `DIRE_HIT`, `X_ATTACK`, `X_DEFEND`, `X_SPEED`,
`X_SPECIAL`, `POKE_DOLL`.

## Berries

Pokémon Red has no Berry item. Mod items whose id contains `BERRY`, or whose
definition explicitly requests the `berries` pocket, are routed here.

## Other Items

`MOON_STONE`, `FIRE_STONE`, `THUNDER_STONE`, `WATER_STONE`, `LEAF_STONE`,
`ESCAPE_ROPE`, `REPEL`, `SUPER_REPEL`, `MAX_REPEL`, plus the unused stock ids
`ITEM_2C` and `ITEM_32`.

Unknown mod items also fall back here unless their definition supplies a
supported `pocket` or `category` value.

## TMs & HMs

Every id beginning with `TM_` or `HM_`. This covers all 50 TMs and five HMs
without maintaining a move-name duplicate list.

## Treasures

`NUGGET`.

## Key Items

`TOWN_MAP`, `BICYCLE`, `SURFBOARD`, `POKEDEX`, `OLD_AMBER`, `DOME_FOSSIL`,
`HELIX_FOSSIL`, `SECRET_KEY`, `BIKE_VOUCHER`, `CARD_KEY`, `COIN`, `S_S_TICKET`,
`GOLD_TEETH`, `COIN_CASE`, `OAKS_PARCEL`, `ITEMFINDER`, `SILPH_SCOPE`,
`POKE_FLUTE`, `LIFT_KEY`, `EXP_ALL`, `OLD_ROD`, `GOOD_ROD`, `SUPER_ROD` and
the internal `FLOOR_*` elevator entries.

Any other item whose extracted or mod-authored definition has `keyItem = true`
is also routed here.

## Compatibility rules

- Authored `pocket` / `category` metadata wins when it names a supported
  pocket.
- TM/HM prefixes and the stock catalog are evaluated next.
- Berry-prefixed and extracted Key Item definitions are recognized after that.
- Everything else uses Other Items.
- Badges never enter a pocket because Gen1Recomp stores them in the inventory
  table but excludes them from `Bag.order`.

The real Pokémon Red ROM catalog test assigns every one of its 144 non-badge
item definitions exactly once, including unused/internal ids.

## Opening and sorting

- Each new Bag opens on the first non-empty pocket in the order documented
  above.
- Available sorts are Type (TM/HM number in the Machines pocket), Name,
  Newest First and Favorites First.
- Favorites and the selected sort mode persist with the save.
- Sorting is view-only and never rewrites `save.inventory` or `save.bagOrder`.
