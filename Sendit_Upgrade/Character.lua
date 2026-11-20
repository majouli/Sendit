--[[
  Character: a snapshot of the player's live stats (talents and buffs included) and what it becomes when
  item stats change - only the changes go through the conversions.
  Character.Snapshot(gear) -> s | nil;  Character.Apply(s, delta, weapons) -> copy of s
  Character.SpellPower(s, school) = live school bonus + delta
  Conversions: strength / agility -> attack power (GetAttackPowerForStat); agility -> crit, intellect
  -> spell crit (GetCritChanceFromStat / GetSpellCritChanceFromStat, else Calibrate, else the Classic
  level-60 ratio scaled by level, marked estimated); item procs from parsed tooltips; school spell
  damage only for that school; melee- / ranged-only hit and crit only for that attack.
  Druid forms: s.form "cat" | "bear" (GetShapeshiftFormID 1 Cat, 8 Dire Bear, 5 Bear); the live values
  hold the form's bonuses, Specs/Druid.lua takes them out. Druid agility gives no attack power outside
  Cat Form (reference "Attack power", Classic).
]]
local _, ns = ...

local Character = {}
ns.Character = Character

local HP_PER_STA = 10     -- reference "Attributes (pre-6.0)": 10 health per stamina
local MANA_PER_INT = 15   -- same page: 15 mana per intellect
local ARMOR_PER_AGI = 2   -- same page: 2 armor per agility
local DEF_PCT = 0.04      -- "Defense" (pre-6.0): each point = 0.04% miss/dodge/parry/block
local STR_PER_BLOCK = 20  -- Classic: 1 block value per 20 strength (shield users)
-- Ranged attack power per agility, Classic (reference "Attack power"):
-- Hunters 2, Warriors and Rogues 1; others do not use ranged attack power.
local RAP_PER_AGI = { HUNTER = 2, WARRIOR = 1, ROGUE = 1 }
-- GetSpellBonusDamage / GetSpellCritChance school index (2 = holy ... 7 = arcane)
local SCHOOL_INDEX = { holy = 2, fire = 3, nature = 4, frost = 5, shadow = 6, arcane = 7 }
Character.SCHOOL_INDEX = SCHOOL_INDEX
local FORMS = { [1] = "cat", [5] = "bear", [8] = "bear" }  -- GetShapeshiftFormID

-- Agility per 1% melee crit at level 60, Classic (reference "Critical
-- strike"; vanilla-wow wiki). Same ratio gives dodge for these classes.
local AGI_PER_CRIT_60 = {
    WARRIOR = 20, PALADIN = 20, HUNTER = 53, ROGUE = 29, DRUID = 20,
    SHAMAN = 20, MAGE = 20, PRIEST = 20, WARLOCK = 20,
}
-- Intellect per 1% spell crit at level 60 (community figures, uncertain).
local INT_PER_SPELLCRIT_60 = {
    PALADIN = 29.5, MAGE = 59.5, PRIEST = 59.2, WARLOCK = 60.6, DRUID = 60, SHAMAN = 59.2,
    WARRIOR = 60, ROGUE = 60, HUNTER = 60,
}

-- Rogues and Hunters get dodge from agility at twice their crit rate
-- (reference "Dodge", Classic: 14.5 / 26.5 agility per 1% at 60 vs
-- 29 / 53 for crit); everyone else at the same rate.
local DODGE_PER_CRIT = { ROGUE = 0.5, HUNTER = 0.5 }

local function Estimate(table60, class, level)
    return (table60[class] or 20) * math.max(level, 10) / 60
end

-- Agility per 1% crit below 60 is not linear in the level. Known points
-- (level, agility per 1%) - Forever client read: Paladin 12.8 / Shaman 13.3 at
-- level 38, 19.8 / 19.7 at 60; Paladin 12.93 at 42 = live calibration of a
-- level 42 Ret (two samples, 60 / 69 agility). Between points linear; below
-- the first point scaled with the level; classes without points: Estimate.
-- the live calibration (Calibrate.lua) wins over all of this
local AGI_PER_CRIT_POINTS = {
    PALADIN = { { 38, 12.8 }, { 42, 12.93 }, { 60, 19.8 } },
    SHAMAN = { { 38, 13.3 }, { 60, 19.7 } },
}

local function AgiPerCrit(class, level)
    local pts = AGI_PER_CRIT_POINTS[class]
    if not pts then return Estimate(AGI_PER_CRIT_60, class, level) end
    if level <= pts[1][1] then return pts[1][2] * math.max(level, 10) / pts[1][1] end
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        if level <= b[1] then return a[2] + (b[2] - a[2]) * (level - a[1]) / (b[1] - a[1]) end
    end
    return pts[#pts][2]
end
Character.AgiPerCrit = AgiPerCrit

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    if issecretvalue and (issecretvalue(a) or issecretvalue(b) or issecretvalue(c)) then return nil end
    return a, b, c
end

local function Effective(index)
    local _, effective = Read(UnitStat, "player", index)
    return effective
end

local function GearSum(gear, key)
    local sum = 0
    for _, item in pairs(gear) do sum = sum + (item.stats[key] or 0) end
    return sum
end

function Character.Snapshot(gear)
    local _, class = Read(UnitClass, "player")
    local s = {
        class = class, level = Read(UnitLevel, "player"),
        str = Effective(1), agi = Effective(2), sta = Effective(3), int = Effective(4), spi = Effective(5),
        crit = Read(GetCritChance), spellCrit = Read(GetSpellCritChance, 2),
        spellDmg = Read(GetSpellBonusDamage, 2), heal = Read(GetSpellBonusHealing),
        hit = Read(GetHitModifier) or 0, spellHit = Read(GetSpellHitModifier) or 0,
        hp = Read(UnitHealthMax, "player"), mana = Read(UnitPowerMax, "player", 0),
        dodge = Read(GetDodgeChance), parry = Read(GetParryChance) or 0, block = Read(GetBlockChance) or 0,
        blockValue = Read(GetShieldBlock) or 0,
    }
    local base, pos, neg = Read(UnitAttackPower, "player")  -- neg is <= 0
    if base then s.ap = base + (pos or 0) + (neg or 0) end
    local _, armor = Read(UnitArmor, "player")
    s.armor = armor
    local rbase, rpos, rneg = Read(UnitRangedAttackPower, "player")
    s.rap = rbase and (rbase + (rpos or 0) + (rneg or 0)) or 0
    s.rangedCrit = Read(GetRangedCritChance) or s.crit
    s.rangedHit = s.hit
    s.form = FORMS[Read(GetShapeshiftFormID) or 0]
    s.schoolDmg, s.schoolCrit = {}, {}
    for school, index in pairs(SCHOOL_INDEX) do
        s.schoolDmg[school] = Read(GetSpellBonusDamage, index) or s.spellDmg
        s.schoolCrit[school] = Read(GetSpellCritChance, index) or s.spellCrit
    end
    for _, key in ipairs({ "class", "level", "str", "agi", "sta", "int", "spi", "crit", "spellCrit",
                           "spellDmg", "heal", "hp", "mana", "dodge", "ap", "armor" }) do
        if s[key] == nil then return nil end
    end

    s.apPerStr = (Read(GetAttackPowerForStat, 1, 100) or 0) / 100
    s.apPerAgi = class == "DRUID" and 0 or (Read(GetAttackPowerForStat, 2, 100) or 0) / 100
    s.mp5 = GearSum(gear, "mp5")
    s.procDps = GearSum(gear, "procDps")
    s.defMiss = 0
    s.weapon = gear[16] and gear[16].weapon or nil
    s.offhand = gear[17]
    s.offWeapon = gear[17] and gear[17].weapon or nil
    s.rangedWeapon = gear[18] and gear[18].weapon or nil
    s.rapPerAgi = RAP_PER_AGI[class] or 0
    -- assumption: a hunter shoots the vendor arrows of the level (Mobs.Ammo);
    -- the ammo slot is not read
    s.ammoDps = class == "HUNTER" and ns.Mobs.Ammo(s.level) or 0
    -- the player's choice on the page (Settings.lua): target level
    s.targetLevel = s.level + ns.Settings.TargetDelta()
    s.feralAp = GearSum(gear, "feralAp")  -- only counts in Cat / Bear form (Specs/Druid.lua)
    s.baseSpellDmg, s.baseSpellCrit = s.spellDmg, s.spellCrit
    s.schoolAdd = {}
    s.liveAgi, s.liveFeralAp, s.liveArmor, s.liveInt = s.agi, s.feralAp, s.armor, s.int

    local ratios = ns.Calibrate and ns.Calibrate.Ratios(s.level) or {}
    -- the client's conversion first (exact for class and level)
    local function PerPercent(fn, index)
        local f = Read(fn, index, 100)
        if type(f) == "number" and f > 0 then return 1 / f end
    end
    local clientAgi = PerPercent(GetCritChanceFromStat, 2)
    local clientInt = PerPercent(GetSpellCritChanceFromStat, 4)
    s.agiPerCrit = clientAgi or ratios.agi or AgiPerCrit(class, s.level)
    s.intPerSpellCrit = clientInt or ratios.int or Estimate(INT_PER_SPELLCRIT_60, class, s.level)
    s.measured = { agi = (clientAgi or ratios.agi) ~= nil, int = (clientInt or ratios.int) ~= nil }
    s.agiPerDodge = s.agiPerCrit * (DODGE_PER_CRIT[class] or 1)
    s.gearCrit = GearSum(gear, "crit")
    s.gearSpellCrit = GearSum(gear, "spellCrit")
    return s
end

local function Copy(s)
    local c = {}
    for k, v in pairs(s) do c[k] = v end
    return c
end

-- Spell power and crit for one school: the live school values plus what the
-- item change adds (deltas land in spellDmg / spellCrit).
function Character.SpellPower(s, school)
    return (s.schoolDmg and s.schoolDmg[school] or s.baseSpellDmg or s.spellDmg) + (s.spellDmg - (s.baseSpellDmg or s.spellDmg))
        + (s.schoolAdd and s.schoolAdd[school] or 0)
end

function Character.SpellCrit(s, school)
    return (s.schoolCrit and s.schoolCrit[school] or s.baseSpellCrit or s.spellCrit) + (s.spellCrit - (s.baseSpellCrit or s.spellCrit))
end

function Character.Apply(s, d, weapons)
    local c = Copy(s)
    local function get(key) return d[key] or 0 end
    c.str = c.str + get("str")
    c.agi = c.agi + get("agi")
    c.sta = c.sta + get("sta")
    c.int = c.int + get("int")
    c.spi = c.spi + get("spi")
    c.ap = c.ap + get("str") * c.apPerStr + get("agi") * c.apPerAgi + get("ap")
    c.crit = c.crit + get("agi") / c.agiPerCrit + get("crit") + get("critMelee")
    c.spellCrit = c.spellCrit + get("int") / c.intPerSpellCrit + get("spellCrit")
    c.spellDmg = c.spellDmg + get("spellDmg")
    c.heal = c.heal + get("heal")
    c.hit = c.hit + get("hit") + get("hitMelee")
    c.rangedHit = (c.rangedHit or s.hit) + get("hit") + get("hitRanged")
    c.spellHit = c.spellHit + get("spellHit")
    c.hp = c.hp + get("sta") * HP_PER_STA
    c.mana = c.mana + get("int") * MANA_PER_INT
    c.mp5 = c.mp5 + get("mp5")
    c.procDps = c.procDps + get("procDps")
    c.armor = c.armor + get("armor") + get("agi") * ARMOR_PER_AGI
    c.dodge = c.dodge + get("agi") / (c.agiPerDodge or c.agiPerCrit) + get("def") * DEF_PCT + get("dodge")
    c.parry = c.parry + get("def") * DEF_PCT + get("parry")
    c.block = c.block + get("def") * DEF_PCT + get("block")
    c.defMiss = c.defMiss + get("def") * DEF_PCT
    c.blockValue = c.blockValue + get("blockValue") + get("str") / STR_PER_BLOCK
    c.rap = (c.rap or 0) + get("agi") * (c.rapPerAgi or 0) + get("rap") + get("ap")
    c.rangedCrit = (c.rangedCrit or c.crit) + get("agi") / c.agiPerCrit + get("crit") + get("critRanged")
    c.schoolAdd = {}
    for school in pairs(SCHOOL_INDEX) do
        c.schoolAdd[school] = (s.schoolAdd and s.schoolAdd[school] or 0) + get(school .. "Dmg")
    end
    c.feralAp = (c.feralAp or 0) + get("feralAp")
    if weapons ~= nil and type(weapons) ~= "table" or (type(weapons) == "table" and weapons.min) then
        weapons = { main = weapons }  -- a plain weapon (or false) = the main hand
    end
    if weapons then
        if weapons.main ~= nil then c.weapon = weapons.main or nil end
        if weapons.off ~= nil then c.offWeapon = weapons.off or nil end
        if weapons.ranged ~= nil then c.rangedWeapon = weapons.ranged or nil end
    end
    return c
end
