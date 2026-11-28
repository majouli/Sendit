--[[
  Slots: the outfit slots, their client names and model slots, and what a class can wear.
  Slots.ORDER = { key, ... } (paper doll order);  Slots.Of(inventoryType) -> key | nil
  Slots.Name(key) (client text);  Slots.Equipped(key) -> inventory slot ID;  Slots.Hand(key) -> model hand
  Slots.Icon(key) (empty-slot picture) / ItemIcon(itemID, key) (the item's, else the slot's)
  Slots.Class() -> classFile, classID | nil;  Slots.Wears(kind, inventoryType, classFile) -> bool
  Slots.ArmorOf(classFile) -> 401..404;  kind = item class * 100 + subclass (Data/Items.lua)
]]
local _, ns = ...
local Slots = {}
ns.Slots = Slots

Slots.ORDER = { "head", "shoulder", "back", "chest", "shirt", "tabard", "wrist", "hands", "waist", "legs",
    "feet", "main", "off", "ranged" }

local OF = { [1] = "head", [3] = "shoulder", [16] = "back", [5] = "chest", [20] = "chest", [4] = "shirt",
    [19] = "tabard", [9] = "wrist", [10] = "hands", [6] = "waist", [7] = "legs", [8] = "feet", [13] = "main",
    [17] = "main", [21] = "main", [14] = "off", [22] = "off", [23] = "off", [15] = "ranged", [25] = "ranged",
    [26] = "ranged" }
Slots.TWO_HAND = 17

-- client slot text (Interface/GlobalStrings), the character's inventory slot ID, the character
-- frame's empty-slot picture
local INFO = {
    head = { "HEADSLOT", 1, "Head" }, shoulder = { "SHOULDERSLOT", 3, "Shoulder" }, back = { "BACKSLOT", 15, "Chest" },
    chest = { "CHESTSLOT", 5, "Chest" }, shirt = { "SHIRTSLOT", 4, "Shirt" }, tabard = { "TABARDSLOT", 19, "Tabard" },
    wrist = { "WRISTSLOT", 9, "Wrists" }, hands = { "HANDSSLOT", 10, "Hands" }, waist = { "WAISTSLOT", 6, "Waist" },
    legs = { "LEGSSLOT", 7, "Legs" }, feet = { "FEETSLOT", 8, "Feet" }, main = { "MAINHANDSLOT", 16, "MainHand" },
    off = { "SECONDARYHANDSLOT", 17, "SecondaryHand" }, ranged = { "RANGEDSLOT", 18, "Ranged" },
}
local UNKNOWN_ICON = 134400  -- the question mark the client shows for an item without a picture

function Slots.Of(inv) return OF[inv] end
function Slots.Name(key) return Sendit.Locale.Global(INFO[key][1]) or key end
function Slots.Equipped(key) return INFO[key][2] end
function Slots.Icon(key) return "Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. INFO[key][3] end

-- the item's picture; an item whose picture the client lacks shows its slot's empty picture
function Slots.ItemIcon(id, key)
    local icon = ns.Read(C_Item.GetItemIconByID, id)
    if (type(icon) == "number" and icon ~= UNKNOWN_ICON) or (type(icon) == "string" and icon ~= "") then return icon end
    return key and Slots.Icon(key) or UNKNOWN_ICON
end

function Slots.Hand(key) return (key == "main" or key == "off") and INFO[key][1] or nil end

-- armour a class trains last (plate from level 40 for warriors and paladins; transmog keeps the type)
local ARMOR = { WARRIOR = 404, PALADIN = 404, HUNTER = 403, SHAMAN = 403, ROGUE = 402, DRUID = 402,
    MAGE = 401, PRIEST = 401, WARLOCK = 401 }
-- weapon subclasses a class can learn (classic reference)
local WEAPONS = {
    WARRIOR = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 },
    PALADIN = { 0, 1, 4, 5, 6, 7, 8 },
    HUNTER = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 },
    ROGUE = { 2, 3, 4, 7, 13, 15, 16, 18 },
    PRIEST = { 4, 10, 15, 19 },
    SHAMAN = { 0, 1, 4, 5, 10, 13, 15 },
    MAGE = { 7, 10, 15, 19 },
    WARLOCK = { 7, 10, 15, 19 },
    DRUID = { 4, 5, 10, 13, 15 },
}
local SHIELD = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local weaponSet = {}
for class, list in pairs(WEAPONS) do
    weaponSet[class] = {}
    for _, sub in ipairs(list) do weaponSet[class][sub] = true end
end

function Slots.Class()
    local _, file, id = ns.Read(UnitClass, "player")
    if type(file) == "string" then return file, id end
end

function Slots.ArmorOf(class) return ARMOR[class] end

function Slots.Wears(kind, inv, class)
    if not class or not ARMOR[class] then return true end
    local cls, sub = math.floor(kind / 100), kind % 100
    if cls == 2 then return weaponSet[class][sub] == true end
    if kind == 406 then return SHIELD[class] == true end
    if kind >= 401 and kind <= 404 and inv ~= 16 then return kind == ARMOR[class] end
    return true
end
