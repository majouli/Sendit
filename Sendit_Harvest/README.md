# Sendit Harvest

Shows in the tooltip what your professions get out of things: material,
amount, chance and auction house price.

| Profession   | Tooltip of ...  | Also                                                         |
|--------------|-----------------|--------------------------------------------------------------|
| Disenchanting| items           |                                                              |
| Skinning     | beasts          | skill needed; new Forever beasts estimated; recognised by name in dungeons |
| Mining       | ore veins       | skill needed, how often a vein can be mined                  |
| Herbalism    | plants          | skill needed, extra finds                                    |

## Usage
- **/harvest** (or /dei) opens the Harvest page in the Sendit window;
  right-click the Sendit minimap button to switch all tooltip lines on / off.
- By default only the professions your character knows (detected
  automatically). Every profession has its own switch.
- The language is the suite's (Sendit Design page).

## Auction house prices
Every visit to the auction house quietly fetches the prices of all
materials. When you search yourself, the scan waits and then goes on.
Materials nobody offers are searched again at most once an hour. The price
shown is a robust one: the cheapest 15 % of the offered units.

## Dribbler (disenchanting gold simulation)
`/harvest dribbler`, the Harvest page or the disenchant tab beside the
auction house open it. Start the mode: your gold is noted, then pick an item
level range (21-25, 26-30, ...). The list shows the disenchantable armour and
weapons of that range, cheapest first, each with its expected mat value
(chance x average count x mat price, after the 5 % auction house cut) and
the profit. One click buys the cheapest auction of a row. Bought items go to
the mailbox; once in the bags, the disenchant button disenchants the next
one per click (the client allows no more). Shortcuts around the click limit:
hover the disenchant button and turn the mouse wheel - every wheel step is a
key press for the client and disenchants one item; "Buy the best deal" buys
the cheapest offer with a profit without aiming at a row; at the mailbox the
bought items are taken out by themselves while the mode runs (only as many
as were bought, never cash-on-delivery mail). Finish the mode for the summary:
gold change, spent, mats received and their worth, items left, profit.

Ranges go by item level, not required level: item level decides the mats
for 1931 of 1936 disenchantable items (required level: 1228). The auction
house filters by required level only, so the query asks ten levels lower
and the list filters by item level.

## Installation
Part of the Sendit suite: `Sendit_Harvest` needs the folder `Sendit` next to
it in `World of Warcraft\_forever_\Interface\AddOns\`.

---

## Development

The code has no comments by choice; the rationale lives here.

### Layout
| Folder         | Content                                                        |
|----------------|----------------------------------------------------------------|
| `Data/`        | tables. `Disenchant.lua` kept by hand, all others generated    |
| `Locales/`     | `Locales.lua` (follows the suite's language) and one file per language |
| `Core/`        | settings, profession detection, prices, auction house scan     |
| `Professions/` | what disenchanting, skinning and gathering yield               |
| `UI/`          | tooltip, page in the Sendit window                             |

The load order is in `Sendit_Harvest.toc`.

### New Forever version
Never edit the generated tables (`Data/Skinning.lua`, `Mining.lua`,
`Herbalism.lua`, `ItemNames.lua`) by hand; generate them again:

```
python tools/gen_professions.py --build <client build>
```

The build number is on wago.tools (e.g. `1.60.1.70862`). The script fetches
every source into a cache and rewrites the files. Then run `tools/check.ps1`
and raise `## Version` in the `.toc`.

New language: add `Locales/<code>.lua`, enter it in `Locales/Locales.lua`, in
`LANGUAGES` of the generator and in the `.toc` - and in the suite's
`Sendit.Locale.LANGUAGES`, so every module offers it.
