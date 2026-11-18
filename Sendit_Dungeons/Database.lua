--[[
  Database: the bundled dungeons (Data/Dungeons.lua, generated) as the window
  needs them - names in the chosen language, the fit to the player's level,
  search and filter.

  Database.All() -> dungeons in level order (Forever's own, levels unknown, last)
  Database.Get(map) -> dungeon or nil
  Database.Name(d) / BossName(boss)   client names, English if a language lacks one;
      map 0 = Forever's world bosses (Locale name, boss names English)
  Database.Kind(d) -> "Dungeon" / "Raid" / "Open world"
  Database.Loot(boss) -> { { itemID, chance }, ... } biggest chance first
  Database.Fit(d, level) -> "fits" | "above" | "below" | "unknown"
      fits: level min .. max + 2 (a dungeon still drops useful items a little
      past its range); above: not enterable yet (level < min)
  Database.Enterable(d, level) -> level reached (or unknown)
  Database.Search(text, filter, level) -> dungeons
      text matches the dungeon or one of its bosses (any case, plain text);
      filter "all" | "fits" | "dungeons" | "raids"
]]
local _, ns = ...
local DB = {}
ns.Database = DB
local byMap = {}
for _, d in ipairs(ns.dungeons) do byMap[d.map] = d end
local PAST_RANGE = 2

local function Names()
    return ns.dungeonNames[Sendit.Locale.Code()] or ns.dungeonNames.enUS
end

function DB.All() return ns.dungeons end
function DB.Get(map) return byMap[map] end

function DB.Name(d)
    if d.map == 0 then return ns.L.worldBosses end  -- Forever's world bosses: no client map
    return Names().maps[d.map] or ns.dungeonNames.enUS.maps[d.map] or ("#" .. d.map)
end

function DB.BossName(boss)
    if boss.name then return boss.name end  -- world bosses: English names (no client table)
    return Names().bosses[boss.enc] or ns.dungeonNames.enUS.bosses[boss.enc] or ("#" .. boss.enc)
end

function DB.Kind(d)
    if d.map == 0 then return ns.L.openWorld end
    return d.raid and ns.L.raid or ns.L.dungeon
end

function DB.Loot(boss)
    local out = {}
    for i = 1, #boss.loot, 2 do out[#out + 1] = { boss.loot[i], boss.loot[i + 1] } end
    return out
end

function DB.Enterable(d, level)
    return not level or d.min == 0 or d.min <= level
end

function DB.Fit(d, level)
    if not level or d.min == 0 then return "unknown" end
    if level < d.min then return "above" end
    if level > d.max + PAST_RANGE then return "below" end
    return "fits"
end

local function Matches(d, needle)
    if needle == "" then return true end
    if DB.Name(d):lower():find(needle, 1, true) then return true end
    for _, boss in ipairs(d.bosses) do
        if DB.BossName(boss):lower():find(needle, 1, true) then return true end
    end
    return false
end

local FILTERS = {
    all = function() return true end,
    fits = function(d, level) return DB.Fit(d, level) == "fits" end,
    dungeons = function(d) return not d.raid end,
    raids = function(d) return d.raid end,
}

function DB.Search(text, filter, level)
    local needle = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local keep = FILTERS[filter] or FILTERS.all
    local out = {}
    for _, d in ipairs(ns.dungeons) do
        if keep(d, level) and Matches(d, needle) then out[#out + 1] = d end
    end
    return out
end

-- nil when the client keeps the level secret.
function DB.Level()
    local ok, level = pcall(UnitLevel, "player")
    if not ok or (issecretvalue and issecretvalue(level)) or type(level) ~= "number" then return nil end
    return level
end
