local _, ns = ...

local Disenchant = {}
ns.Disenchant = Disenchant

local CLASS_WEAPON, CLASS_ARMOR = 2, 4
local NOT_DISENCHANTABLE = { [""] = true, INVTYPE_BODY = true, INVTYPE_TABARD = true }
local WEAPON_LIKE = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }

function Disenchant.LootID(itemID, quality, itemLevel, classID, equipLoc)
    if classID ~= CLASS_WEAPON and classID ~= CLASS_ARMOR then return nil end
    if NOT_DISENCHANTABLE[equipLoc or ""] then return nil end
    local exact = itemID and ns.DisenchantItems[itemID]
    if exact ~= nil then return exact ~= 0 and exact or nil end
    local class = (classID == CLASS_WEAPON or WEAPON_LIKE[equipLoc]) and CLASS_WEAPON or CLASS_ARMOR
    for _, b in ipairs(ns.DisenchantBrackets) do
        if b[1] == class and b[2] == quality and itemLevel >= b[3] and itemLevel <= b[4] then return b[5] end
    end
    return nil
end

function Disenchant.Yield(lootID)
    local loot = lootID and ns.DisenchantLoot[lootID]
    if not loot then return nil end
    local out = {}
    for i = 1, #loot, 4 do
        local item = loot[i]
        out[#out + 1] = { item = item, chance = loot[i + 1] / 100, min = loot[i + 2], max = loot[i + 3],
                          kind = ns.MatKinds[item] }
    end
    return out
end

local function ItemID(item)
    if type(item) == "number" then return item end
    local instant = C_Item.GetItemInfoInstant
    local id = instant and instant(item)
    return type(id) == "number" and id or nil
end

function Disenchant.ForItem(item)
    local _, _, quality, itemLevel, _, _, _, _, equipLoc, _, _, classID = C_Item.GetItemInfo(item)
    if not quality or not itemLevel then return nil end
    return Disenchant.Yield(Disenchant.LootID(ItemID(item), quality, itemLevel, classID, equipLoc))
end
