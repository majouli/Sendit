--[[
  Database: the bundled dungeons (Data/Dungeons.lua) - names, level fit, search and filter.
  Database.All() -> dungeons in level order;  Database.Get(id)   id = map, a wing 100000 + activity
  Database.Name(d) / BossName(boss)   client names, English fallback; map 0 = world bosses; a wing by
                                      its group finder activity; a rare
                                      (enc 0) by its NPC ID
  Database.Kind(d) -> "Dungeon" | "Raid" | "Open world"
  Database.Loot(boss) -> { { itemID, chance }, ... } biggest chance first
  Database.Drops(d) -> a boss-like card of what drops anywhere in the instance (d.drops) | nil
  Database.Fit(d, level) -> "fits" (min .. max + 2) | "above" | "below" | "unknown"
  Database.Enterable(d, level);  Database.Search(text, filter, level)
]]
local _, ns = ...
local DB = {}
ns.Database = DB
local byId = {}
for _, d in ipairs(ns.dungeons) do byId[d.id] = d end
local PAST_RANGE = 2

local function Names()
    return ns.dungeonNames[Sendit.Locale.Code()] or ns.dungeonNames.enUS
end

function DB.All() return ns.dungeons end
function DB.Get(id) return byId[id] end

function DB.Name(d)
    if d.map == 0 then return ns.L.worldBosses end
    if d.wing then return Names().wings[d.wing] or ns.dungeonNames.enUS.wings[d.wing] or ("#" .. d.wing) end
    return Names().maps[d.map] or ns.dungeonNames.enUS.maps[d.map] or ("#" .. d.map)
end

function DB.BossName(boss)
    if boss.drops then return ns.L.dungeonDrops end
    if boss.name then return boss.name end
    if boss.enc == 0 then
        return Names().npcs[boss.npc] or ns.dungeonNames.enUS.npcs[boss.npc] or ("#" .. boss.npc)
    end
    return Names().bosses[boss.enc] or ns.dungeonNames.enUS.bosses[boss.enc] or ("#" .. boss.enc)
end

function DB.Kind(d)
    if d.map == 0 then return ns.L.openWorld end
    return d.raid and ns.L.raid or ns.L.dungeon
end

-- what drops anywhere in the instance, as a card like a boss's (no portrait, no number) | nil
local dropCards = {}
function DB.Drops(d)
    if not d.drops then return nil end
    local card = dropCards[d]
    if not card then
        card = { drops = true, display = 0, known = true, loot = {} }
        for _, item in ipairs(d.drops) do
            card.loot[#card.loot + 1] = item
            card.loot[#card.loot + 1] = 0
        end
        dropCards[d] = card
    end
    return card
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

function DB.Level()
    local ok, level = pcall(UnitLevel, "player")
    if not ok or (issecretvalue and issecretvalue(level)) or type(level) ~= "number" then return nil end
    return level
end
