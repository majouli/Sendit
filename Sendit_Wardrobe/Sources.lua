--[[
  Sources: where an item - or any item of a look - comes from, as rows the UI can show and click.
  Sources.For(itemID) -> { entry, ... } easiest first;  Sources.ForLook(look) -> entries of all its items
  entry = { kind, group, icon, title, detail, item, action = fn | nil, hint = text | nil, off = true when
            the player cannot use it (other faction, quest already done) }
  Sources.Groups(look) -> { [group] = true } for the source filter (auction counts only when listed)
  Sources.Price(look) -> copper, itemID of its cheapest listing | nil;  Sources.Money(copper) -> text
  Groups: auction vendor quest crafted dungeon drop pvp rep special unknown.
  Generated tokens (Data/Items.lua) + services "dungeons", "quests", "auctionPrices" (nil: module off).
]]
local _, ns = ...
local L, Catalog = ns.L, ns.Catalog
local Sources = {}
ns.Sources = Sources
local groupCache = {}

local ICON = {
    auction = "Interface\\Icons\\INV_Misc_Coin_02", vendor = "Interface\\GossipFrame\\VendorGossipIcon",
    quest = "Interface\\GossipFrame\\AvailableQuestIcon", dungeon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
    raid = "Interface\\Icons\\INV_Misc_Head_Dragon_01", drop = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
    world = "Interface\\Icons\\INV_Misc_Map_01", container = "Interface\\Icons\\INV_Box_01",
    item = "Interface\\Icons\\INV_Misc_Bag_07", crafted = "Interface\\Icons\\INV_Misc_Note_01",
    rep = "Interface\\Icons\\INV_Scroll_03", special = "Interface\\Icons\\INV_Misc_Gift_01",
}
local CRAFT_ICON = { [164] = "Interface\\Icons\\Trade_BlackSmithing", [165] = "Interface\\Icons\\Trade_LeatherWorking",
    [197] = "Interface\\Icons\\Trade_Tailoring", [202] = "Interface\\Icons\\Trade_Engineering",
    [333] = "Interface\\Icons\\Trade_Engraving" }
local ORDER = { auction = 1, vendor = 2, quest = 3, crafted = 4, rep = 5, special = 6, dungeon = 7, raid = 7,
    drop = 8, container = 9, item = 10, world = 11, pvp = 12 }
local GROUP = { raid = "dungeon", world = "drop", container = "drop", item = "drop" }
local TOKEN_GROUP = { v = "vendor", n = "drop", w = "drop", o = "drop", i = "drop", c = "crafted", p = "pvp",
    x = "special" }

function Sources.Money(copper)
    copper = math.floor(copper or 0)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = ("%d|cffffd700g|r"):format(g) end
    if s > 0 then parts[#parts + 1] = ("%d|cffc7c7cfs|r"):format(s) end
    if c > 0 or #parts == 0 then parts[#parts + 1] = ("%d|cffeda55fc|r"):format(c) end
    return table.concat(parts, " ")
end

local function Side()
    local f = ns.Read(UnitFactionGroup, "player")
    return f == "Alliance" and "A" or f == "Horde" and "H" or nil
end

local function Where(kind, id)
    local map, x, y, side = Catalog.Place(kind, id)
    return map, x, y, side, map and ns.Waypoint.Zone(map)
end

local function Pin(entry, kind, id)
    local map, x, y = Catalog.Place(kind, id)
    if not map then return end
    entry.action = function() ns.Waypoint.Set(map, x, y, entry.title) end
    entry.hint = L.hintWaypoint
end

local function Npc(kind, npc, item, extra)
    local _, _, _, side, zone = Where("npcs", npc)
    local e = { kind = kind, item = item, title = Catalog.Name("npcs", npc) or ("#" .. npc),
        detail = ns.Join(zone or L.unknownPlace, extra) }
    local mine = Side()
    if mine and side and side ~= "" and not side:find(mine, 1, true) then
        e.off, e.detail = true, ns.Join(e.detail, L.otherFaction)
    end
    Pin(e, "npcs", npc)
    return e
end

local function Standing(rank)
    return _G["FACTION_STANDING_LABEL" .. ((tonumber(rank) or 0) + 1)] or tostring(rank)
end

local function Tokens(it, out)
    local price, rep
    for _, t in ipairs(it.src) do
        local k, rest = t:sub(1, 1), t:sub(2)
        if k == "$" then price = tonumber(rest) end
        if k == "r" then rep = rest end
    end
    local repText
    if rep then
        local f, rank = rep:match("^(%d+):(%d+)$")
        repText = L.repNeed:format(Standing(rank), Catalog.Name("factions", tonumber(f)) or ("#" .. f))
    end
    local vendors = 0
    for _, t in ipairs(it.src) do
        local k, rest = t:sub(1, 1), t:sub(2)
        if k == "v" then
            vendors = vendors + 1
            out[#out + 1] = Npc("vendor", tonumber(rest), it.id,
                ns.Join(price and Sources.Money(price) or nil, repText))
        elseif k == "n" then
            local npc, chance = rest:match("^(%d+):?([%d.]*)$")
            out[#out + 1] = Npc("drop", tonumber(npc), it.id, chance ~= "" and L.chance:format(chance) or nil)
        elseif k == "w" then
            out[#out + 1] = { kind = "world", item = it.id, title = L.worldDrop, detail = L.worldDropFrom:format(rest) }
        elseif k == "o" then
            local o = tonumber(rest)
            local map = Catalog.Place("objects", o)
            local e = { kind = "container", item = it.id, title = Catalog.Name("objects", o) or ("#" .. o),
                detail = map and ns.Waypoint.Zone(map) or L.unknownPlace }
            Pin(e, "objects", o)
            out[#out + 1] = e
        elseif k == "i" then
            out[#out + 1] = { kind = "item", item = it.id, title = Catalog.ItemName(tonumber(rest)), detail = L.inside,
                link = tonumber(rest) }
        elseif k == "c" then
            local skill, rank = rest:match("^(%d+):(%d+)$")
            skill = tonumber(skill)
            out[#out + 1] = { kind = "crafted", item = it.id, icon = CRAFT_ICON[skill],
                title = Catalog.Name("skills", skill) or L.crafted, detail = L.skillRank:format(rank) }
        elseif k == "p" then
            out[#out + 1] = { kind = "pvp", item = it.id, icon = ("Interface\\PvPRankBadges\\PvPRank%02d"):format(tonumber(rest) - 4),
                title = L.pvp, detail = L.pvpRank:format(rest) }
        elseif k == "x" then
            out[#out + 1] = { kind = "special", item = it.id, title = L["src_" .. rest] or rest, detail = L.srcSpecial }
        end
    end
    if repText and vendors == 0 then
        out[#out + 1] = { kind = "rep", item = it.id, title = L.reputation, detail = repText }
    end
end

local function Services(it, out)
    local dungeons = Sendit.Service("dungeons")
    for _, d in ipairs(dungeons and dungeons.Drops(it.id) or {}) do
        out[#out + 1] = { kind = d.raid and "raid" or "dungeon", item = it.id, title = d.dungeon,
            detail = ns.Join(d.bossName, (d.chance or 0) > 0 and L.chance:format(d.chance) or nil),  -- 0: too few kills recorded
            action = function() dungeons.Open(d.id, d.boss) end, hint = L.hintDungeon }
    end
    local quests = Sendit.Service("quests")
    local mine = Side()
    for _, q in ipairs(quests and quests.Rewarding(it.id) or {}) do
        local other = mine and q.faction and (q.faction == "alliance" and "A" or "H") ~= mine
        local detail = ns.Join(L.questLevel:format(q.level), q.choice and L.questChoice or nil,
            q.done and L.questDone or nil, other and L.otherFaction or nil)
        out[#out + 1] = { kind = "quest", item = it.id, title = q.name, detail = detail,
            off = q.done or other, action = function() quests.Open(q.id) end, hint = L.hintQuest }
    end
    local prices = it.boe and Sendit.Service("auctionPrices")
    local unit, count = nil, nil
    if prices then unit, count = prices.Get(it.id) end
    if unit then
        out[#out + 1] = { kind = "auction", item = it.id, title = L.auction,
            detail = Sources.Money(unit) .. "  ·  " .. L.listed:format(count or 1), price = unit }
    end
end

local function Finish(out)
    for _, e in ipairs(out) do
        e.group = GROUP[e.kind] or e.kind
        e.icon = e.icon or ICON[e.kind]
    end
    table.sort(out, function(a, b)
        if (a.off or false) ~= (b.off or false) then return not a.off end
        if ORDER[a.kind] ~= ORDER[b.kind] then return ORDER[a.kind] < ORDER[b.kind] end
        return (a.price or 0) < (b.price or 0)
    end)
    return out
end

function Sources.For(id)
    local it = Catalog.Item(id)
    if not it then return {} end
    local out = {}
    Services(it, out)
    Tokens(it, out)
    return Finish(out)
end

function Sources.ForLook(look)
    local out, seen = {}, {}
    for _, id in ipairs(look.items) do
        for _, e in ipairs(Sources.For(id)) do
            local key = e.kind .. "|" .. e.title .. "|" .. (e.kind == "auction" and "" or e.detail)
            if not seen[key] then
                seen[key] = true
                out[#out + 1] = e
            end
        end
    end
    return Finish(out)
end

function Sources.Price(look)
    local prices = Sendit.Service("auctionPrices")
    if not prices then return nil end
    local best, bestItem
    for _, id in ipairs(look.items) do
        local it = Catalog.Item(id)
        local unit = it and it.boe and prices.Get(id)
        if unit and (not best or unit < best) then best, bestItem = unit, id end
    end
    return best, bestItem
end

-- static groups (generated data and services) are cached; auction asks the prices every time
function Sources.Groups(look)
    local g = groupCache[look.id]
    if not g then
        g = {}
        local dungeons, quests = Sendit.Service("dungeons"), Sendit.Service("quests")
        for _, id in ipairs(look.items) do
            local vendor, rep = false, false
            for _, t in ipairs(Catalog.Item(id).src) do
                local k = t:sub(1, 1)
                if TOKEN_GROUP[k] then g[TOKEN_GROUP[k]] = true end
                vendor, rep = vendor or k == "v", rep or k == "r"
            end
            if rep and not vendor then g.rep = true end
            if dungeons and dungeons.Drops(id) then g.dungeon = true end
            if quests and quests.Rewarding(id) then g.quest = true end
        end
        if not next(g) then g.unknown = true end
        groupCache[look.id] = g
    end
    if Sources.Price(look) then
        local copy = { auction = true }
        for k in pairs(g) do if k ~= "unknown" then copy[k] = true end end
        return copy
    end
    return g
end

Sendit.OnModuleSwitch(function() wipe(groupCache) end)
