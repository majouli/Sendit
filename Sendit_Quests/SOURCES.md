# Sendit Quests sources

This module is licensed under GPL-3.0; see LICENSE.md. Its implementation
is original Sendit code. Generated data retains its upstream attribution.

- Quest records: https://github.com/Questie/QuestieDB/tree/4f628e8328ed8923ffba169c8b432996e0a7a326
  (GPL-3.0, Questie contributors): data/Forever/foreverQuestDB.lua with its Forever
  Static Corrections (legacy, generated delta-base from Forever scans, traces, authored
  fixes), applied by Sendit's own reader (tools/questie_forever.lua); no QuestieDB code runs.
- Item rewards the server data lacks and fixed XP figures: https://github.com/zmarotrix/NorgannonDB/tree/7e1368e755b2cc6ef76f0199aa624cb02526e00b
  (data/quests.lua, GPL-3.0, compiled by Maro from QuestieDB, pfQuest by Shagu (MIT),
  DungeonJournal by Exehn (used with the author's permission, credited), cmangos classic-db
  and in-game sightings of the NorgannonDB Collector). Its item lists carry no amounts
  (assumed 1) and mostly no fixed/choice split (several items count as a choice).
- Item, money and XP rewards: https://github.com/tyler3497/forever-quests/tree/9f4c5aac2d077854d7f4a2bdc2f8eceb8d7b23af
  (data/quests.json, GPL-3.0, from TrinityCore's Forever world database), for the
  5393 quests it covers; reputation rewards come from QuestieDB.
  SHA-256 of input: e79cb39ddba55cc66a5238b07f83c5a16e3f8521b847cc2cdc641a52bb776c46.
  0 quest(s) only there are kept as they are. 14 "<NYI>" placeholder
  quests (not in the game) are left out; 5 link(s) to quests no source knows
  are dropped.
- Localized names and objectives: QuestieDB l10n/Forever/lookupQuests, overlaid by
  l10n/Forever/traces/lookupQuests (live-client scans), same revision.
- Quest giver, turn-in and objective positions (Data/Places.lua): NorgannonDB data/npcs.lua,
  data/objects.lua and its quest givers (Forever sightings), QuestieDB data/Forever
  foreverNpcDB.lua and foreverObjectDB.lua for the rest, zones mapped to client maps
  with wago.tools DB2 UiMapAssignment, build 1.60.1.70938.
- Places/categories: wago.tools DB2 AreaTable and QuestSort CSV, build 1.60.1.70938,
  enUS/deDE/frFR/esES/ruRU. Only names referenced by bundled quests are retained.
- API/layout reference: Gethe/wow-ui-source, forever branch,
  QuestLogDocumentation.lua and Mainline/QuestMapFrame.xml.
- Money comes from GetQuestLogRewardMoney(questID) only when HaveQuestData confirms data;
  offline money difficulty/bonus fields are not presented as final amounts. Branch totals
  are a catalog, not a promise that mutually exclusive quests can all be completed.

Regenerate with `python tools/gen_quests.py` (pinned) or `--update` (newest QuestieDB).
6063 quests; localized titles: {'deDE': 5790, 'frFR': 5726, 'esES': 5413, 'ruRU': 5690}.

Coverage is QuestieDB's Forever data at the pinned revision, not a guarantee of all
quests or links in the live client. Quests without item rewards may simply be missing
them in the sources. Missing titles fall back to English. Quest progress is read from the
current character; absence of completion does not imply that a quest is available.
