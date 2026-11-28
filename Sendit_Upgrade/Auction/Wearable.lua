--[[
  Wearable: whether the character has the proficiency for an armor or weapon item - for auction
  data without the client's "usable" flag (the web data). Proficiency = the skill's spell (client
  SpellName: Cloth 9078, Leather 9077, Mail 8737, Plate Mail 750, Shield 9116, weapon skills below).
  Subclasses without a skill (misc armor, relics, misc weapons) count as wearable.
  Wearable.Can(itemID) -> bool
  Wearable.Types() -> { armor = { type }, weapons = { type } }: the armor and weapon types the character
    can use, type = { key = "class:subclass", name = client subclass name in the suite language }; shields sit with the weapons
  Wearable.TypeKey(itemID, equipLoc) -> "class:subclass" | nil (no type: cloaks are cloth for every class)
]]
local _, ns = ...
local Wearable = {}
ns.AuctionWearable = Wearable

local E = Enum or {}
local CLASS = E.ItemClass or { Weapon = 2, Armor = 4 }
local ARMOR = E.ItemArmorSubclass or { Cloth = 1, Leather = 2, Mail = 3, Plate = 4, Shield = 6 }
local WEAPON = E.ItemWeaponSubclass or {
    Axe1H = 0, Axe2H = 1, Bows = 2, Guns = 3, Mace1H = 4, Mace2H = 5, Polearm = 6, Sword1H = 7,
    Sword2H = 8, Staff = 10, Unarmed = 13, Dagger = 15, Thrown = 16, Crossbow = 18, Wand = 19,
}

local SKILL = {
    [CLASS.Armor] = {
        [ARMOR.Cloth] = 9078, [ARMOR.Leather] = 9077, [ARMOR.Mail] = 8737, [ARMOR.Plate] = 750,
        [ARMOR.Shield] = 9116,
    },
    [CLASS.Weapon] = {
        [WEAPON.Axe1H] = 196, [WEAPON.Axe2H] = 197, [WEAPON.Bows] = 264, [WEAPON.Guns] = 266,
        [WEAPON.Mace1H] = 198, [WEAPON.Mace2H] = 199, [WEAPON.Polearm] = 200, [WEAPON.Sword1H] = 201,
        [WEAPON.Sword2H] = 202, [WEAPON.Staff] = 227, [WEAPON.Unarmed] = 15590, [WEAPON.Dagger] = 1180,
        [WEAPON.Thrown] = 2567, [WEAPON.Crossbow] = 5011, [WEAPON.Wand] = 5009,
    },
}

local legacyKnown = "IsPlayerSpell"

local function Knows(spell)
    local fn = (C_SpellBook and C_SpellBook.IsSpellKnown) or _G[legacyKnown]
    if not fn then return true end
    local ok, known = pcall(fn, spell)
    return not ok or known == true
end

function Wearable.Can(itemID)
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    local skills = classID and SKILL[classID]
    local spell = skills and subclassID and skills[subclassID]
    return spell == nil or Knows(spell)
end

local ARMOR_ORDER = { ARMOR.Cloth, ARMOR.Leather, ARMOR.Mail, ARMOR.Plate }
local WEAPON_ORDER = {
    WEAPON.Axe1H, WEAPON.Mace1H, WEAPON.Sword1H, WEAPON.Dagger, WEAPON.Unarmed, WEAPON.Axe2H, WEAPON.Mace2H,
    WEAPON.Sword2H, WEAPON.Polearm, WEAPON.Staff, WEAPON.Bows, WEAPON.Crossbow, WEAPON.Guns, WEAPON.Thrown,
    WEAPON.Wand,
}

local legacySubName = "GetItemSubClassInfo"

local function Name(classID, subclassID)
    local own = Sendit.Locale.SubClass(classID, subclassID)
    if own then return own end
    local fn = (C_Item and C_Item.GetItemSubClassInfo) or _G[legacySubName]
    local ok, name = pcall(fn, classID, subclassID)
    return ok and type(name) == "string" and name ~= "" and name or (classID .. ":" .. subclassID)
end

local function Add(list, classID, subclassID)
    if Knows(SKILL[classID][subclassID]) then
        list[#list + 1] = { key = classID .. ":" .. subclassID, name = Name(classID, subclassID) }
    end
end

function Wearable.Types()
    local armor, weapons = {}, {}
    for _, sub in ipairs(ARMOR_ORDER) do Add(armor, CLASS.Armor, sub) end
    for _, sub in ipairs(WEAPON_ORDER) do Add(weapons, CLASS.Weapon, sub) end
    Add(weapons, CLASS.Armor, ARMOR.Shield)
    return { armor = armor, weapons = weapons }
end

function Wearable.TypeKey(itemID, equipLoc)
    if equipLoc == "INVTYPE_CLOAK" then return nil end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    local skills = classID and SKILL[classID]
    if not (skills and subclassID and skills[subclassID]) then return nil end
    return classID .. ":" .. subclassID
end
