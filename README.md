# Sendit

*That's what we do.*

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

| Module | What it does |
|---|---|
| **Sendit** (core) | The Sendit window, the Design page (colour palette, frame style, animations, language), profiles and the minimap button. Every module needs it. |
| **Fade** | Detects every UI element, from Blizzard and from any addon, and fades it out while nothing is going on. Combat, a target, casting, the mouse, typing, group chat or loot bring it back. Optional cinema look while the addon Spoken reads quests aloud. |
| **Chat** | A calm chat: movable windows, detachable tabs, your own tabs for channels and message kinds, the combat log with its filters in the same look, whispers in one messenger window with a friends list, your own loot and loot rolls summed up in one line each. |
| **GearScore** | GearScore on items, on your character and on every player you hover or inspect, plus the inspected player's talents. |
| **Harvest** | Tooltip lines for what disenchanting, skinning, mining and herbalism yield, with auction house prices. |
| **Upgrade** | Rates items by recalculating your character: how much more damage, healing or survival an item really gives you - for every class and its talent trees. Alt-click any item to compare it with yours. |
| **Quests** | Search quests and explore their chains offline. |
| **Dungeons** | Dungeons, their bosses and what they drop - with how much each item would improve your gear. |

## Getting started

- `/sendit` (or the minimap button) opens the window. Every module has its
  own pages there.
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

Sendit Harvest, Quests and Dungeons are GPL-3.0 (see their licence files).
