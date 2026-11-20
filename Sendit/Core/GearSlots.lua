--[[
  GearSlots: the slot groups a gear boost filters by (Quests, Dungeons).
  Sendit.GearSlots.GROUPS = { { key, locs = { equipLoc, ... }, own = locale key | nil } }
  GearSlots.Group(equipLoc) -> key | nil;  GearSlots.Label(group, L) -> the client's slot name or L[own]
  GearSlots.On(db, key) / Set(db, key, on) / Wanted(db, equipLoc)   db.boostSlots[key] = false: off
]]
local _, ns = ...
local GearSlots = {}
ns.GearSlots = GearSlots

GearSlots.GROUPS = {
    { key = "head", locs = { "INVTYPE_HEAD" } }, { key = "neck", locs = { "INVTYPE_NECK" } },
    { key = "shoulder", locs = { "INVTYPE_SHOULDER" } }, { key = "back", locs = { "INVTYPE_CLOAK" } },
    { key = "chest", locs = { "INVTYPE_CHEST", "INVTYPE_ROBE" } }, { key = "wrist", locs = { "INVTYPE_WRIST" } },
    { key = "hands", locs = { "INVTYPE_HAND" } }, { key = "waist", locs = { "INVTYPE_WAIST" } },
    { key = "legs", locs = { "INVTYPE_LEGS" } }, { key = "feet", locs = { "INVTYPE_FEET" } },
    { key = "finger", locs = { "INVTYPE_FINGER" } }, { key = "trinket", locs = { "INVTYPE_TRINKET" } },
    { key = "weapon", locs = { "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND" }, own = "slotWeapon" },
    { key = "offhand", locs = { "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE" }, own = "slotOffhand" },
    { key = "ranged", locs = { "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC" }, own = "slotRanged" },
}
local groupOf = {}
for _, g in ipairs(GearSlots.GROUPS) do for _, loc in ipairs(g.locs) do groupOf[loc] = g.key end end

function GearSlots.Group(equipLoc) return equipLoc and groupOf[equipLoc] end

function GearSlots.On(db, key)
    local slots = db and db.boostSlots
    return not (slots and slots[key] == false)
end

function GearSlots.Set(db, key, on)
    if not db then return end
    db.boostSlots = db.boostSlots or {}
    db.boostSlots[key] = on and true or false
end

-- an item in no group (a bag, a quest item) always counts
function GearSlots.Wanted(db, equipLoc)
    local key = GearSlots.Group(equipLoc)
    return key == nil or GearSlots.On(db, key)
end

function GearSlots.Label(g, L)
    if g.own then return L[g.own] end
    local name = _G[g.locs[1]]
    return type(name) == "string" and name or g.key
end
