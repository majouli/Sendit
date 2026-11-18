# Sendit Quests sources

This module is licensed under GPL-3.0; see LICENSE.md. Its implementation
is original Sendit code. Generated data retains its upstream attribution.

- Quest records: https://github.com/tyler3497/forever-quests/tree/9f4c5aac2d077854d7f4a2bdc2f8eceb8d7b23af
  (data/quests.json, GPL-3.0; derived from QuestieDB, TrinityCore and NorgannonDB).
  SHA-256 of input: e79cb39ddba55cc66a5238b07f83c5a16e3f8521b847cc2cdc641a52bb776c46.
- Localized Forever quest titles and objectives: https://github.com/Questie/QuestieDB/tree/c0718536287f809b5bd2689cbd020435d5601061
  (l10n/Forever/lookupQuests, GPL-3.0, Questie contributors).
- Quest giver, turn-in and objective positions (Data/Places.lua, for "track"): QuestieDB data/Forever
  foreverNpcDB.lua and foreverObjectDB.lua at the same revision (GPL-3.0), zones mapped
  to client maps with wago.tools DB2 UiMapAssignment, build 1.60.1.70938.
- Places/categories: wago.tools DB2 AreaTable and QuestSort CSV, build 1.60.1.70938,
  enUS/deDE/frFR/esES/ruRU. Only names referenced by bundled quests are retained.
- API/layout reference: Gethe/wow-ui-source, forever branch,
  QuestLogDocumentation.lua and Mainline/QuestMapFrame.xml.
- Fixed/choice item rewards retain upstream sources. Money comes from
  GetQuestLogRewardMoney(questID) only when HaveQuestData confirms data.
  Offline money difficulty/bonus fields are not presented as final amounts:
  QuestDef.cpp in advocaite/TrinityCore's forever branch distinguishes classic
  fixed money and max-level bonus money. Branch totals are a catalog, not a
  promise that mutually exclusive quests can all be completed.

Regenerate with `python tools/gen_quests.py`. All revisions are pinned.
4630 quests; localized titles: {'deDE': 4231, 'frFR': 4232, 'esES': 4238, 'ruRU': 4239}.

Coverage is the upstream reference snapshot, not a guarantee of all quests
or all links in live build 1.60.1.70938. Upstream explicitly reports that its
main database has not been fully verified in game. Missing titles fall back
to English. No Classic-only chains are silently substituted. Quest progress
is read from the current character; absence of completion does not imply
that a quest is available (race, class, reputation and other gates exist).
