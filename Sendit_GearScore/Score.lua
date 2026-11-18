--[[
  Score: the GearScore formula, unchanged from the original GearScore /
  GearScoreLite by Mirrikat45 (constants as in LibGearScore-1.0, BSD-2, the
  reference implementation Classic addons share), so the numbers match what
  other GearScore users see:
    item  = floor((ilvl - A) / B * SlotMOD * 1.8618 * QualityScale), >= 0
            A, B per quality from table "A" (ilvl > 120) or "B" (ilvl <= 120);
            legendary = epic row * 1.3, poor/common = uncommon row * 0.005,
            heirloom = rare row at an item level derived from the unit level.
    total = sum over head..ranged (shirt and tabard excluded), floored;
            hunters: main/off hand * 0.3164, ranged * 5.3224;
            main hand + off hand where one is two-handed (Titan's Grip): both * 0.5.
    item level = mean item level of the scored items.
  Colours follow GearScore's brackets on Classic (200 points per quality step:
  grey, white, green, blue, purple, orange), interpolated between steps.
  Contract: Score.Item(link, level) -> score, ilvl | nil (not equippable or not
  cached); Score.Unit(unit) -> { score, ilvl, count, complete };
  Score.Delta(link) -> change of the player's total when equipping link | nil.
]]
local _, ns = ...

local Score = {}
ns.Score = Score

local SCALE = 1.8618
local BRACKET = 200          -- Classic bracket size (Wrath: 1000, TBC: 400)
-- Item colour = item score without slot and quality factor, times the
-- original's set factor, so an item is coloured like a full set of it.
local ITEM_COLOR_FACTOR = 11.25
local HUNTER_MELEE, HUNTER_RANGED, TITAN_GRIP = 0.3164, 5.3224, 0.5

local FORMULA = {
    A = { [4] = { 91.45, 0.65 }, [3] = { 81.375, 0.8125 }, [2] = { 73, 1 } },
    B = { [4] = { 26, 1.2 }, [3] = { 0.75, 1.8 }, [2] = { 8, 2 }, [1] = { 0, 2.25 } },
}

local SLOT_MOD = {
    INVTYPE_RELIC = 0.3164, INVTYPE_TRINKET = 0.5625, INVTYPE_2HWEAPON = 2,
    INVTYPE_WEAPONMAINHAND = 1, INVTYPE_WEAPONOFFHAND = 1, INVTYPE_RANGED = 0.3164,
    INVTYPE_THROWN = 0.3164, INVTYPE_RANGEDRIGHT = 0.3164, INVTYPE_SHIELD = 1,
    INVTYPE_WEAPON = 1, INVTYPE_HOLDABLE = 1, INVTYPE_HEAD = 1, INVTYPE_NECK = 0.5625,
    INVTYPE_SHOULDER = 0.75, INVTYPE_CHEST = 1, INVTYPE_ROBE = 1, INVTYPE_WAIST = 0.75,
    INVTYPE_LEGS = 1, INVTYPE_FEET = 0.75, INVTYPE_WRIST = 0.5625, INVTYPE_HAND = 0.75,
    INVTYPE_FINGER = 0.5625, INVTYPE_CLOAK = 0.5625, INVTYPE_BODY = 0,
}

-- Inventory slots that count: 1-3, 5-18 (4 = shirt, 19 = tabard).
local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local MAIN, OFF, RANGED = 16, 17, 18

-- Where an item goes when the player equips it.
local TARGET = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_RELIC = { 18 },
}

-- Heirlooms scale with the wearer (original GearScore's rule).
local function HeirloomLevel(level)
    if level < 60 then return level end
    if level < 70 then return 3 * (level - 60) + 85 end
    if level <= 80 then return 4 * (level - 70) + 147 end
    return 1
end

-- Base value before slot and quality factor; nil = quality not rated.
local function Base(quality, ilvl, level)
    local qualityScale = 1
    if quality == 5 then
        qualityScale, quality = 1.3, 4
    elseif quality == 0 or quality == 1 then
        qualityScale, quality = 0.005, 2
    elseif quality == 7 then
        quality, ilvl = 3, HeirloomLevel(level or 60)
    end
    if quality < 2 or quality > 4 then return nil end
    local row = (ilvl > 120 and FORMULA.A or FORMULA.B)[quality]
    return (ilvl - row[1]) / row[2], qualityScale, ilvl
end

-- Pure formula (tested): score of one item.
function Score.Formula(quality, ilvl, equipLoc, level)
    local mod = SLOT_MOD[equipLoc]
    if not mod or not quality or not ilvl then return nil end
    local base, qualityScale, effectiveIlvl = Base(quality, ilvl, level)
    if not base then return 0, ilvl end
    local score = math.floor(base * mod * SCALE * qualityScale)
    return math.max(0, score), effectiveIlvl
end

-- Item data; nil while the client has not cached the item (asks for it).
local function Info(link)
    local ok, _, _, quality, ilvl, _, _, _, _, equipLoc = pcall(C_Item.GetItemInfo, link)
    quality, ilvl, equipLoc = ns.Safe(quality), ns.Safe(ilvl), ns.Safe(equipLoc)
    if not ok or not quality or not ilvl then
        if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, link) end
        return nil
    end
    return quality, ilvl, equipLoc
end

function Score.Item(link, level)
    if not link then return nil end
    local quality, ilvl, equipLoc = Info(link)
    if not quality then return nil end
    local score, effectiveIlvl = Score.Formula(quality, ilvl, equipLoc, level)
    return score, effectiveIlvl, quality, equipLoc
end

function Score.EquipLoc(link)
    local _, _, equipLoc = Info(link)
    return equipLoc
end

-- Colour value of a single item (see ITEM_COLOR_FACTOR).
function Score.ItemColorValue(link, level)
    local quality, ilvl = Info(link)
    if not quality then return 0 end
    local base = Base(quality, ilvl, level)
    if not base then return 0 end
    return math.floor(base * SCALE) * ITEM_COLOR_FACTOR
end

-- Total of a gear table { [slot] = link }; incomplete when an item is not cached.
function Score.Total(gear, class, level)
    local hunter = class == "HUNTER"
    local grip = 1
    if gear[MAIN] and gear[OFF] then
        if Score.EquipLoc(gear[MAIN]) == "INVTYPE_2HWEAPON" or Score.EquipLoc(gear[OFF]) == "INVTYPE_2HWEAPON" then
            grip = TITAN_GRIP
        end
    end
    local total, ilvlSum, count, complete = 0, 0, 0, true
    for _, slot in ipairs(SLOTS) do
        local link = gear[slot]
        if link then
            local score, ilvl = Score.Item(link, level)
            if score then
                if slot == MAIN or slot == OFF then
                    if hunter then score = score * HUNTER_MELEE end
                    score = score * grip
                elseif slot == RANGED and hunter then
                    score = score * HUNTER_RANGED
                end
                total, ilvlSum, count = total + score, ilvlSum + ilvl, count + 1
            elseif not Info(link) then
                complete = false
            end
        end
    end
    return {
        score = math.floor(total),
        ilvl = count > 0 and math.floor(ilvlSum / count) or 0,
        count = count,
        complete = complete,
    }
end

-- Equipped items of a unit. A slot with an item ID but no link is not loaded yet.
function Score.Gear(unit)
    local gear, complete = {}, true
    for _, slot in ipairs(SLOTS) do
        local link = ns.Call(GetInventoryItemLink, unit, slot)
        if link then
            gear[slot] = link
        elseif ns.Call(GetInventoryItemID, unit, slot) then
            complete = false
        end
    end
    return gear, complete
end

function Score.Unit(unit)
    local gear, linksComplete = Score.Gear(unit)
    local level = ns.Call(UnitLevel, unit)
    local r = Score.Total(gear, ns.ClassOf(unit), level)
    r.complete = r.complete and linksComplete
    return r
end

-- Change of the player's GearScore when equipping link (best fitting slot).
-- nil when it cannot be worn in a slot or would only unseat a two-hander.
function Score.Delta(link)
    local equipLoc = Score.EquipLoc(link)
    local slots = equipLoc and TARGET[equipLoc]
    if not slots then return nil end
    local gear = Score.Gear("player")
    local class, level = ns.ClassOf("player"), ns.Call(UnitLevel, "player")
    local before = Score.Total(gear, class, level)
    if not before.complete then return nil end
    local mainLoc = gear[MAIN] and Score.EquipLoc(gear[MAIN])
    local best
    for _, slot in ipairs(slots) do
        local usable = true
        if slot == OFF then
            -- an off hand next to a two-hander is not a fair comparison;
            -- a one-hander goes to the off hand only for those who dual wield
            usable = mainLoc ~= "INVTYPE_2HWEAPON"
            if equipLoc == "INVTYPE_WEAPON" then
                local offLoc = gear[OFF] and Score.EquipLoc(gear[OFF])
                usable = usable and (offLoc == "INVTYPE_WEAPON" or offLoc == "INVTYPE_WEAPONOFFHAND")
            end
        end
        if usable then
            local after = {}
            for s, l in pairs(gear) do after[s] = l end
            after[slot] = link
            if equipLoc == "INVTYPE_2HWEAPON" then after[OFF] = nil end
            local d = Score.Total(after, class, level).score - before.score
            if not best or d > best then best = d end
        end
    end
    return best
end

-- Grey, white, green, blue, purple, orange at 0, 200, ... 1000.
local STEPS = {
    { 0.55, 0.55, 0.55 }, { 1, 1, 1 }, { 0.12, 1, 0 },
    { 0, 0.5, 1 }, { 0.69, 0.28, 0.97 }, { 0.94, 0.5, 0 },
}

function Score.Color(value)
    value = math.max(0, value or 0) / BRACKET
    local i = math.floor(value) + 1
    if i >= #STEPS then return unpack(STEPS[#STEPS]) end
    local f, a, b = value - (i - 1), STEPS[i], STEPS[i + 1]
    return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

function Score.Hex(value)
    local r, g, b = Score.Color(value)
    local function byte(x) return math.floor(x * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

function Score.Colored(score)
    return Score.Hex(score) .. tostring(score) .. "|r"
end
