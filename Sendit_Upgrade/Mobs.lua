--[[
  Mobs: the average normal mob of a level - the leveling target.
  Mobs.Armor(level) / Hit(level) / Health(level) / Drink(level) / Ammo(level)
  Source: AzerothCore creature_classlevelstats (class 1, basearmor) - emulator data from Classic
  sniffs, an approximation (shown as estimated).
]]
local _, ns = ...

local Mobs = {}
ns.Mobs = Mobs

-- index = mob level
local ARMOR = {
    8, 20, 33, 68, 111, 165, 230, 306, 387, 463, 528, 562,
    596, 630, 665, 700, 734, 768, 802, 836, 872, 906, 940, 975,
    1008, 1043, 1078, 1111, 1145, 1179, 1213, 1249, 1281, 1317, 1349, 1456,
    1568, 1684, 1808, 1938, 2074, 2218, 2369, 2528, 2695, 2750, 2804, 2857,
    2912, 2966, 3018, 3060, 3128, 3180, 3234, 3289, 3342, 3396, 3449, 3750,
    4047, 4344, 4641,
}

-- Average raw melee hit by mob level: classic server data creature_template_
-- classlevelstats, class 1, (BaseDamageExp0 + BaseMeleeAttackPower / 14) * 2.0
-- (Creature.cpp damage per hit, assumption: a normal mob swings every 2.0 s).
-- Only used for how much a block stops: an estimate, like the armor.
local HIT = {
    2, 2, 3, 4, 5, 7, 9, 10, 12, 13, 15, 17, 18, 20, 22, 23, 25, 26, 28, 29, 31,
    32, 33, 34, 36, 37, 38, 39, 41, 42, 44, 45, 46, 47, 49, 50, 51, 53, 54, 56, 59, 62,
    67, 72, 76, 77, 79, 80, 83, 85, 86, 88, 90, 92, 94, 96, 98, 100, 102, 104, 106, 108, 110,
}

local function Clamp(level, n)
    return math.max(1, math.min(n, math.floor(level or 1)))
end

function Mobs.Armor(level)
    return ARMOR[Clamp(level, #ARMOR)]
end

function Mobs.Hit(level)
    return HIT[Clamp(level, #HIT)]
end

function Mobs.Health(level)
    local t = ns.LevelingData.mobHealth
    return t[Clamp(level, #t)]
end

function Mobs.Drink(level)
    local best = ns.LevelingData.drinks[1]
    for _, d in ipairs(ns.LevelingData.drinks) do
        if d[1] <= (level or 1) then best = d end
    end
    return best[2], best[3]
end

function Mobs.Ammo(level)
    local dps = 0
    for _, a in ipairs(ns.LevelingData.ammo) do
        if a[1] <= (level or 1) then dps = a[2] end
    end
    return dps
end
