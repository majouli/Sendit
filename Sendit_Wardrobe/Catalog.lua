--[[
  Catalog: the bundled looks (Data/Items.lua, Sets.lua, Places.lua, Names_<locale>.lua).
  Catalog.Item(id) -> { id, look, inv, slot, kind, q, lvl, ilvl, classes, boe, src = { token, ... } } | nil
  Catalog.Look(lookID) -> { id, items = { itemID, ... }, slot, kind, q, lvl, special } | nil
  Catalog.Looks() -> every look (slot order, best quality first);  Catalog.LookOf(itemID) -> look
  Catalog.Sets() -> { { key, kind, items, armor, classes, lvl, ilvl, q } } best item level first
  Catalog.Name(kind, id) -> the suite language's name ("items", "npcs", "objects", "sets", "skills",
  "factions"), else English, else the client's item name, else nil
  Catalog.ItemName(id) -> name (never nil);  Catalog.Place(kind, id) -> uiMap, x, y, side | nil
  special (highlights): "unique" | "legendary" | "cosmetic" | "shirt" | "tabard" | nil
  Only the suite language's names stay loaded (and English); a language switch needs /reload.
]]
local _, ns = ...
local Catalog = {}
ns.Catalog = Catalog
local Slots = ns.Slots
local items = {}
local looks, lookList, sets
local ORDER = {}
for i, key in ipairs(Slots.ORDER) do ORDER[key] = i end
local COSMETIC = 405

Sendit.OnReady(function()
    local keep = Sendit.Locale.Code()
    for code in pairs(ns.names) do
        if code ~= keep and code ~= "enUS" then ns.names[code] = nil end
    end
end)

local function Split(s, sep)
    local out = {}
    for part in s:gmatch("[^" .. sep .. "]+") do out[#out + 1] = part end
    return out
end

function Catalog.Item(id)
    local rec = items[id]
    if rec ~= nil then return rec or nil end
    local raw = ns.items[id]
    if not raw then items[id] = false return nil end
    local head, src = raw:match("^([^|]*)|(.*)$")
    local f = Split(head, ",")
    local inv = tonumber(f[2])
    local classes = tonumber(f[6]) or 0
    rec = { id = id, look = tonumber(f[1]), inv = inv, slot = Slots.Of(inv), kind = tonumber(f[3]),
        q = tonumber(f[4]) or 1, lvl = tonumber(f[5]) or 0, classes = classes >= 1535 and 0 or classes,
        boe = f[7] == "1", ilvl = tonumber(f[8]) or 0, src = Split(src or "", ";") }
    items[id] = rec
    return rec
end

local function Special(look)
    local best, curated = 0, false
    for _, id in ipairs(look.items) do
        local it = Catalog.Item(id) or { q = 0, src = {} }
        best = math.max(best, it.q)
        for _, s in ipairs(it.src) do if s:sub(1, 1) == "x" then curated = true end end
    end
    if look.slot == "shirt" then return "shirt" end
    if look.slot == "tabard" then return "tabard" end
    if curated or look.kind == COSMETIC then return "cosmetic" end
    if best >= 5 then return "legendary" end
    if best == 4 and #look.items == 1 then return "unique" end
    return nil
end

local function Build()
    if looks then return end
    looks, lookList = {}, {}
    for id in pairs(ns.items) do
        local it = Catalog.Item(id)
        if it and it.slot then
            local l = looks[it.look]
            if not l then
                l = { id = it.look, items = {}, slot = it.slot, kind = it.kind, q = it.q, lvl = it.lvl }
                looks[it.look] = l
                lookList[#lookList + 1] = l
            end
            table.insert(l.items, id)
            l.q = math.max(l.q, it.q)
            l.lvl = math.min(l.lvl, it.lvl)
        end
    end
    for _, l in ipairs(lookList) do
        table.sort(l.items)
        l.special = Special(l)
    end
    table.sort(lookList, function(a, b)
        if a.slot ~= b.slot then return ORDER[a.slot] < ORDER[b.slot] end
        if a.q ~= b.q then return a.q > b.q end
        return a.id < b.id
    end)
end

function Catalog.Looks() Build() return lookList end
function Catalog.Look(id) Build() return looks[id] end
function Catalog.LookOf(itemID)
    local it = Catalog.Item(itemID)
    return it and Catalog.Look(it.look)
end

local function Most(counts)
    local best, n = nil, 0
    for k, c in pairs(counts) do if c > n then best, n = k, c end end
    return best
end

function Catalog.Sets()
    if sets then return sets end
    sets = {}
    for _, s in ipairs(ns.sets) do
        local armor, classes, lvl, ilvl, q = {}, nil, 0, 0, 0
        for _, id in ipairs(s.items) do
            local it = Catalog.Item(id) or { kind = 0, inv = 0, classes = 0, lvl = 0, ilvl = 0, q = 0 }
            if it.kind >= 401 and it.kind <= 404 and it.inv ~= 16 then armor[it.kind] = (armor[it.kind] or 0) + 1 end
            if it.classes > 0 then classes = it.classes end
            lvl, ilvl, q = math.max(lvl, it.lvl), math.max(ilvl, it.ilvl), math.max(q, it.q)
        end
        sets[#sets + 1] = { key = s.key, kind = s.kind, items = s.items, armor = Most(armor), classes = classes or 0,
            lvl = lvl, ilvl = ilvl, q = q }
    end
    table.sort(sets, function(a, b)
        if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
        return tostring(a.key) < tostring(b.key)
    end)
    return sets
end

function Catalog.Name(kind, id)
    local own = ns.names[Sendit.Locale.Code()]
    local v = own and own[kind] and own[kind][id]
    if v then return v end
    local en = ns.names.enUS
    return en and en[kind] and en[kind][id] or nil
end

function Catalog.ItemName(id)
    return Catalog.Name("items", id) or ns.Read(C_Item.GetItemNameByID, id) or ("#" .. id)
end

function Catalog.Place(kind, id)
    local raw = (kind == "npcs" and ns.npcs or ns.objects)[id]
    if not raw then return nil end
    local f = { strsplit(",", raw) }
    local map = tonumber(f[1]) or 0
    return map > 0 and map or nil, tonumber(f[2]), tonumber(f[3]), f[4] or ""
end
