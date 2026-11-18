# Sendit Dungeons sources

This module is licensed under GPL-3.0; see LICENSE.md. Its implementation
is original Sendit code. Generated data (Data/, tools/gen_dungeons.py) keeps
its upstream attribution.

- Dungeons and bosses, names in enUS/deDE/frFR/esES/ruRU: the Forever client's
  own tables (wago.tools DB2 Map, DungeonEncounter, LFGDungeons, build
  1.60.1.70938). Forever's own dungeons are in there too.
- Boss loot and level ranges: cMaNGOS classic-db (GPL-3.0): creature,
  creature_template, creature_loot_template, reference_loot_template,
  instance_template, instance_dungeon_encounters, instance_encounters.
  Classic data: Forever may have changed drops; Forever's own bosses have no
  loot data in cMaNGOS.
- Forever's own dungeons (levels, boss loot, drop chances) and Ezra Grimm:
  collected from web sources (2026-11-16) into tools/data/
  forever_loot.csv / forever_dungeons.csv; every item ID checked against
  the client's Item table by the generator, drops under 1 % left out like
  the cMaNGOS loot. Bosses without any data say "loot unknown".
- Forever's world bosses (Azuregos, Lord Kazzak, Prince Thunderaan, Super
  Hogger, Voracious) and their loot: collected in game (Forever beta,
  2026-11-16) into tools/data/forever_world_bosses.csv, item IDs checked
  against the client; no client table names them, boss names stay English.
- Item ratings: Sendit Upgrade (the "upgrade" service), the same number as its
  item tooltip.
