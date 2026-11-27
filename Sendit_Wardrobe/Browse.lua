--[[
  Browse: the list of the window's tab under the filter (account: ns.module.db.filter).
  Tabs: sets | highlights | looks | outfits (a set passes the source filter when every piece does).  Filter: slot ("all" | Slots key), armor ("mine" | "all" |
  401..404 cloth leather mail plate), source ("all" | Sources group), have ("all" | "missing" | "have").
  Browse.List(text) -> { { type = "head", text } | { type = "set", set } | { type = "look", look } |
                         { type = "outfit", index, outfit }, ... }, count (rows without heads)
  Browse.Get(key) / Set(key, value);  Browse.Best(look) -> the item to show and wear for a look
]]
local _, ns = ...
local L, Catalog, Collection, Slots, Sources = ns.L, ns.Catalog, ns.Collection, ns.Slots, ns.Sources
local Browse = {}
ns.Browse = Browse
local SPECIAL_ORDER = { "legendary", "unique", "cosmetic", "shirt", "tabard" }

local function Filter()
    local db = ns.module.db
    db.filter = type(db.filter) == "table" and db.filter or {}
    return db.filter
end

function Browse.Get(key) return Filter()[key] end
function Browse.Set(key, value) Filter()[key] = value end

local function ClassBit(id) return id and 2 ^ (id - 1) or nil end

local function Usable(it, class, bit)
    if not Slots.Wears(it.kind, it.inv, class) then return false end
    return it.classes == 0 or not bit or math.floor(it.classes / bit) % 2 == 1
end

local function ArmorFits(it, armor, class, bit)
    if armor == "all" then return true end
    if armor == "mine" then return Usable(it, class, bit) end
    if it.kind >= 401 and it.kind <= 404 and it.inv ~= 16 then return it.kind == armor end
    return true
end

local function Fold(s) return (s or ""):lower() end

local function NameHit(id, needle)
    if Fold(Catalog.ItemName(id)):find(needle, 1, true) then return true end
    local en = ns.names.enUS and ns.names.enUS.items[id]
    return en ~= nil and Fold(en):find(needle, 1, true) ~= nil
end

local function Have(state, want)
    if want == "have" then return state == true end
    if want == "missing" then return state ~= true end
    return true
end

function Browse.Best(look)
    local fallback
    for _, id in ipairs(look.items) do
        local it = Catalog.Item(id)
        if Collection.Item(id) then return id end
        if not fallback and #it.src > 0 then fallback = id end
    end
    return fallback or look.items[1]
end

local function LookPasses(look, f, needle, class, bit)
    if f.slot ~= "all" and look.slot ~= f.slot then return false end
    local fits = false
    for _, id in ipairs(look.items) do
        if ArmorFits(Catalog.Item(id), f.armor, class, bit) then fits = true break end
    end
    if not fits then return false end
    if f.source ~= "all" and not Sources.Groups(look)[f.source] then return false end
    if not Have(Collection.Look(look), f.have) then return false end
    if needle then
        for _, id in ipairs(look.items) do if NameHit(id, needle) then return true end end
        return false
    end
    return true
end

local function SetPasses(set, f, needle, class, bit)
    if f.armor == "mine" then
        if set.armor and set.armor ~= Slots.ArmorOf(class) then return false end
        if set.classes > 0 and bit and math.floor(set.classes / bit) % 2 == 0 then return false end
    elseif f.armor ~= "all" and set.armor ~= f.armor then
        return false
    end
    if f.source ~= "all" then
        for _, id in ipairs(set.items) do
            local look = Catalog.LookOf(id)
            if not (look and Sources.Groups(look)[f.source]) then return false end
        end
    end
    if f.have ~= "all" then
        local have, total = Collection.Count(set.items)
        if f.have == "have" and have < total then return false end
        if f.have == "missing" and have == total then return false end
    end
    if needle then
        if Fold(Catalog.Name("sets", set.key)):find(needle, 1, true) then return true end
        for _, id in ipairs(set.items) do if NameHit(id, needle) then return true end end
        return false
    end
    return true
end

function Browse.List(text)
    local f = Filter()
    f.tab, f.slot, f.armor = f.tab or "sets", f.slot or "all", f.armor or "mine"
    f.source, f.have = f.source or "all", f.have or "all"
    local needle = text and strtrim(text) ~= "" and Fold(strtrim(text)) or nil
    local class, classID = Slots.Class()
    local bit = ClassBit(classID)
    local out, count = {}, 0
    if f.tab == "sets" then
        for _, set in ipairs(Catalog.Sets()) do
            if SetPasses(set, f, needle, class, bit) then
                out[#out + 1] = { type = "set", set = set }
                count = count + 1
            end
        end
    elseif f.tab == "outfits" then
        for i, o in ipairs(ns.Outfit.Saved()) do
            if not needle or Fold(o.name):find(needle, 1, true) then
                out[#out + 1] = { type = "outfit", index = i, outfit = o }
                count = count + 1
            end
        end
    else
        local special = f.tab == "highlights"
        local groups, lastSlot = {}, nil
        for _, look in ipairs(Catalog.Looks()) do
            if (not special or (look.special and not Sources.Groups(look).unknown))
                and LookPasses(look, f, needle, class, bit) then
                count = count + 1
                if special then
                    groups[look.special] = groups[look.special] or {}
                    table.insert(groups[look.special], { type = "look", look = look })
                else
                    if f.slot == "all" and look.slot ~= lastSlot then
                        out[#out + 1] = { type = "head", text = Slots.Name(look.slot) }
                        lastSlot = look.slot
                    end
                    out[#out + 1] = { type = "look", look = look }
                end
            end
        end
        for _, key in ipairs(special and SPECIAL_ORDER or {}) do
            if groups[key] then
                out[#out + 1] = { type = "head", text = L["special_" .. key] }
                for _, e in ipairs(groups[key]) do out[#out + 1] = e end
            end
        end
    end
    return out, count
end
