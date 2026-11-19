<p align="center">
  <img src=".github/sendit-logo.png" width="128" alt="Sendit logo">
</p>

<h1 align="center">Sendit</h1>

<p align="center"><em>That's what we do.</em></p>

> **Beta.** Sendit is in active development for **WoW Forever**. Things can
> still change between versions - bug reports are very welcome.

**One suite, one look, one window.** Sendit replaces a pile of single-purpose
addons with modules that share a design, a language and your profiles. Pick a
palette once and every window follows - from a calm chat to item ratings that
actually recalculate your character.

- **Designed, not stacked:** three palettes (Dusk, Light, Wood) and two frame
  styles - clean modern lines or the game's own gold borders.
- **Five languages, switched live:** English, Deutsch, Français, Español,
  Русский - no reload.
- **Built for the Forever client:** Blizzard's own frames stay untouched
  underneath, so the game's protected actions keep working.
- **Take only what you need:** every module can be turned off on its own.
- **Your apps one click away:** a movable app bar slides out the module windows:
  Messenger, Upgrade, Quests, Dungeons and the Dribbler.

| Module | What it does |
|---|---|
| **Sendit** (core) | The Sendit window, the Design page (colour palette, frame style, animations, language), profiles, the minimap button and the app bar. Every module needs it. |
| **Fade** | Detects every UI element, from Blizzard and from any addon, and fades it out while nothing is going on. Combat, a target, casting, the mouse, typing, group chat or loot bring it back. Optional cinema look while the addon Spoken reads quests aloud. |
| **Chat** | A calm chat: movable windows, detachable tabs, your own tabs for channels and message kinds, the combat log with its filters in the same look, whispers in one messenger window with a friends list, your own loot and loot rolls summed up in one line each. |
| **GearScore** | GearScore on items, on your character and on every player you hover or inspect, plus the inspected player's talents. |
| **Harvest** | Tooltip lines for what disenchanting, skinning, mining and herbalism yield, with auction house prices. The **Dribbler** turns disenchanting into a gold run: buy disenchantables at the auction house sorted by profit, disenchant them with one click each and see what the session earned. |
| **Upgrade** | Rates items by recalculating your character: how much more damage, healing or survival an item really gives you - for every class and its talent trees. Alt-click any item to compare it with yours. |
| **Quests** | Over 6,000 WoW Forever quests offline, kept current from QuestieDB and NorgannonDB: search every text, item, NPC or ID (with wildcards), explore whole chains with their rewards, right-click any quest - done or not - for a map pin on its giver, objective or turn-in, and jump in from Blizzard's quest log. |
| **Dungeons** | Dungeons, their bosses and what they drop - with how much each item would improve your gear. |
| **Talents** | A leveling talent route for every class tree, right in Blizzard's talent window: the next talent glows, free points are numbered in buying order, a fold-out timeline lists all 51 points (hover a row to find its talent). The route adapts when you go your own way. |

## Getting started

- `/sendit` (or the minimap button) opens the window. Every module has its
  own pages there.
- **App bar:** click the round Sendit handle to slide out the module windows,
  drag it anywhere, right-click it for the Sendit window. Switch it off under
  Design if you do not want it.
- **Dribbler:** open the auction house and click the disenchant tab at its
  right edge, start the mode and buy from the list.
- **Talents:** open the talent window; pick a route bottom left (one is
  suggested) and fold the timeline out with the map tab on the right.
- **Design** sets the look and language for all modules: palettes Dusk, Light
  and Wood; frame style Modern (fine lines) or Azeroth (the game's gold
  borders, banners and seals).
- **Languages:** English, Deutsch, Français, Español, Русский. Automatic
  follows the game.
- **Profiles** hold the design plus the settings of every module. Pick one and
  it applies at once; all characters of the account can share it.

## Commands

| Command | |
|---|---|
| `/sendit` | the Sendit window (`/sendit profile <name>`, `/sendit <page>`) |
| `/fade`, `/fa` | Fade's pages |
| `/chat` | the messenger (`/chat reset`, `/chat off`, `/chat on`) |
| `/gs`, `/gearscore` | GearScore's page (`/gs score`, `/gs auto`) |
| `/harvest`, `/dei` | Harvest's page |
| `/upgrade`, `/gc` | the compare window (`/gc spec ret\|holy\|prot\|auto`) |
| `/sq` | Quests |
| `/sd` | Dungeons |

## Installation

With WowUp: install from this repository's latest release. By hand: unpack
the release zip into `World of Warcraft\_forever_\Interface\AddOns\` (it holds
one folder per module) and restart the game.

## Licence

The whole suite is free software under the GNU GPL-3.0 (`LICENSE.md`).
