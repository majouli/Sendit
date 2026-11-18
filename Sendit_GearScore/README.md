# Sendit GearScore

GearScore and talents for WoW Forever, in one small addon.

- **Item tooltips:** the GearScore of the item, its item level, and how much
  *your* total would change if you equipped it (`GearScore 88 (+11)`).
  No change is shown for items you cannot use.
- **Player tooltips:** GearScore, item level and talent spec with points
  (`Retribution 5/11/35`) of every player you hover. Known players show at
  once; others are inspected automatically (never in combat, never while
  your inspect window is open).
- **Character window:** a GearScore row at the top of the stats list
  (hover it for your average item level).
- **Inspect window:** the inspected player's GearScore under their name, plus a
  **Talents** tab under the PvP tab: their talent trees drawn like the game's
  talent window, with ranks and spell tooltips; drag the corner to resize it.

The score is the original GearScore formula (Mirrikat45's GearScore /
GearScoreLite, as used by Classic GearScore addons), including the hunter
weapon weights and the two-hander rule, so the numbers match other
GearScore users. Colours follow the Classic brackets (200 points per step:
grey, white, green, blue, purple, orange).

Languages: English, German, French, Spanish, Russian (follows the game client).

## Commands

| Command | What it does |
|---|---|
| `/gs` (or `/gearscore`) | GearScore page of the Sendit window (your score on top) |
| `/gs score` | Print your GearScore |
| `/gs auto` | Turn automatic inspect on hover on or off |
| `/gs reset` | Forget all known players |
| `/gs probe` | API check for bug reports (target a player first) |
