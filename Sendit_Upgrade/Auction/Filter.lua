--[[
  Filter: the upgrade scan's settings per character (Sendit_UpgradeCharDB.auction) and the tests an
  auction passes. Settings: boostSlots (Sendit.GearSlots), qualities ([quality] = false: off), minLevel /
  maxLevel (required level; nil = 1 / the own level), maxGold (highest buyout in gold; nil = any),
  minGain (least gain in %; nil = any upgrade), types (["class:subclass"] = false: armor / weapon type
  off, Auction/Wearable.lua), sort ("gain" | "price" | "value" = gain per gold; nil = gain).
  Filter.Settings() / Level() / Range() -> lo, hi / Slot(equipLoc) / Price(buyout) / Item(quality, reqLevel)
  Filter.Quality(q) / SetQuality(q, on) / Gain(pct) / Type(itemID, equipLoc) / TypeOn(key) / SetType(key, on)
  Filter.Sort() / SetSort(mode); Filter.SORTS
]]
local _, ns = ...
local Slots, Wearable = Sendit.GearSlots, ns.AuctionWearable
local Filter = {}
ns.AuctionFilter = Filter

Filter.QUALITIES = { 0, 1, 2, 3, 4 }
Filter.SORTS = { "gain", "price", "value" }
local isSecret = issecretvalue or function() return false end

function Filter.Settings()
    local char = ns.charDB or {}
    char.auction = char.auction or {}
    local db = char.auction
    db.qualities = db.qualities or {}
    db.types = db.types or {}
    return db
end

function Filter.Level()
    local ok, level = pcall(UnitLevel, "player")
    if not ok or isSecret(level) or type(level) ~= "number" then return 1 end
    return level
end

function Filter.Range()
    local db = Filter.Settings()
    return db.minLevel or 1, db.maxLevel or Filter.Level()
end

function Filter.Slot(equipLoc)
    local group = Slots.Group(equipLoc)
    return group ~= nil and Slots.On(Filter.Settings(), group)
end

function Filter.Price(buyout)
    local gold = Filter.Settings().maxGold
    return gold == nil or buyout <= gold * 10000
end

function Filter.Quality(q) return Filter.Settings().qualities[q] ~= false end

function Filter.SetQuality(q, on) Filter.Settings().qualities[q] = on and true or false end

function Filter.Gain(pct)
    local min = Filter.Settings().minGain
    return min == nil or pct >= min
end

function Filter.Item(quality, reqLevel)
    local lo, hi = Filter.Range()
    local req = math.max(1, reqLevel or 1)
    return Filter.Quality(quality or 0) and req >= lo and req <= hi
end

function Filter.TypeOn(key) return Filter.Settings().types[key] ~= false end

function Filter.SetType(key, on) Filter.Settings().types[key] = on and true or false end

function Filter.Type(itemID, equipLoc)
    local key = Wearable.TypeKey(itemID, equipLoc)
    return key == nil or Filter.TypeOn(key)
end

function Filter.Sort()
    local mode = Filter.Settings().sort
    return (mode == "price" or mode == "value") and mode or "gain"
end

function Filter.SetSort(mode) Filter.Settings().sort = mode end
