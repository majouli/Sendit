--[[
  Stats: reads one item into canonical stats the model understands.
  Contract: ns.Stats.Read(link) -> item or nil (item data not cached yet)
    item.stats   { str = 5, sta = 9, armor = 168, ... } (keys: ns.Stats.KEYS)
    item.weapon  { min, max, speed, dps } for weapons, else nil
    item.unrated { "Anlegen: Fügt jedes Mal, wenn Ihr blockt ...", ... }
    item.effects green lines rated through Effects.lua (enchants, damage procs);
                 their stats are already in item.stats / item.weapon
    item.red     red tooltip texts: what the player cannot use (proficiency, class,
                 level) - the client colours these for the current character
    item.equipLoc, item.quality, item.level, item.minLevel, item.classID,
    item.subclassID, item.name, item.link
  The cache is per link; Stats.ClearCache() after a level-up (red lines change).

  Source of truth is C_Item.GetItemStats: /gc probe showed it already contains
  the green "Equip:" effects (attack power, spell damage, healing, mp5, defense).
  Hit / crit / dodge / parry / block come as ratings and are turned into percent
  (Stats.Percent); one crit or hit rating counts for melee and spells.
  The tooltip is read only to (1) get weapon damage and speed and (2) find
  green lines no stat explains. A green line is explained when one of its
  numbers equals a stat value not claimed by another line - language-independent,
  so no German/English text patterns can drift. The rest goes to Effects.Parse
  (enchants, damage procs); what it does not understand (use effects, set
  bonuses, other procs) goes to item.unrated and is shown, never dropped.
]]
local _, ns = ...

local Stats = {}
ns.Stats = Stats

-- GetItemStats key -> canonical key. Spell power (damage AND healing) is split
-- into both on read.
local API_KEYS = {
    ITEM_MOD_STRENGTH_SHORT = "str", ITEM_MOD_AGILITY_SHORT = "agi",
    ITEM_MOD_STAMINA_SHORT = "sta", ITEM_MOD_INTELLECT_SHORT = "int",
    ITEM_MOD_SPIRIT_SHORT = "spi",
    RESISTANCE0_NAME = "armor",
    RESISTANCE1_NAME = "resHoly", RESISTANCE2_NAME = "resFire", RESISTANCE3_NAME = "resNature",
    RESISTANCE4_NAME = "resFrost", RESISTANCE5_NAME = "resShadow", RESISTANCE6_NAME = "resArcane",
    ITEM_MOD_ATTACK_POWER_SHORT = "ap", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rap",
    ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "feralAp",
    ITEM_MOD_SPELL_POWER_SHORT = "spellPower", ITEM_MOD_SPELLPOWER_SHORT = "spellPower",
    -- Classic Era 1.15 names spell power without _SHORT (SimGear Forever Stats.lua,
    -- /dump in game 2026-10-28); counted only when the _SHORT key is not there too
    ITEM_MOD_SPELL_POWER = "spellPower",
    -- one school's spell damage: in GetItemStats on Forever (SimGear Forever harvest,
    -- 2026-10-17: 52 fire, 80 frost, 24 arcane, 58 shadow items)
    ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = "fireDmg", ITEM_MOD_FROST_DAMAGE_DONE_SHORT = "frostDmg",
    ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT = "arcaneDmg", ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = "shadowDmg",
    ITEM_MOD_HOLY_DAMAGE_DONE_SHORT = "holyDmg", ITEM_MOD_NATURE_DAMAGE_DONE_SHORT = "natureDmg",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "spellDmg", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "heal",
    ITEM_MOD_MANA_REGENERATION_SHORT = "mp5", ITEM_MOD_HEALTH_REGENERATION_SHORT = "hp5",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "def",
    ITEM_MOD_DODGE_RATING_SHORT = "dodge", ITEM_MOD_PARRY_RATING_SHORT = "parry",
    ITEM_MOD_BLOCK_RATING_SHORT = "block", ITEM_MOD_BLOCK_VALUE_SHORT = "blockValue",
    -- RATINGS (below): Forever stores Classic's "+1 %" as rating points
    ITEM_MOD_HIT_RATING_SHORT = "hit", ITEM_MOD_CRIT_RATING_SHORT = "crit",
    ITEM_MOD_HIT_SPELL_RATING_SHORT = "spellHit", ITEM_MOD_CRIT_SPELL_RATING_SHORT = "spellCrit",
    ITEM_MOD_HIT_MELEE_RATING_SHORT = "hitMelee", ITEM_MOD_HIT_RANGED_RATING_SHORT = "hitRanged",
    ITEM_MOD_CRIT_MELEE_RATING_SHORT = "critMelee", ITEM_MOD_CRIT_RANGED_RATING_SHORT = "critRanged",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "dps",
}

-- Keys that are another key's other name: skipped when that one is there too.
local SAME_AS = { ITEM_MOD_SPELL_POWER = "ITEM_MOD_SPELL_POWER_SHORT" }

-- Forever stores Classic's "+1 %" stats as ratings (GetItemStats says 14 for 1 % crit);
-- rating per 1 % confirmed in game by SimGear Forever (Stats.RATING_PER_POINT, items 868 /
-- 15056 / 12639, GetCombatRatingBonusForCombatRatingValue at level 22: no level scaling).
-- The client's own conversion is asked first.
local RATINGS = {
    crit = { 14, "CR_CRIT_MELEE" }, critMelee = { 14, "CR_CRIT_MELEE" }, critRanged = { 14, "CR_CRIT_RANGED" },
    spellCrit = { 14, "CR_CRIT_SPELL" },
    hit = { 10, "CR_HIT_MELEE" }, hitMelee = { 10, "CR_HIT_MELEE" }, hitRanged = { 10, "CR_HIT_RANGED" },
    spellHit = { 10, "CR_HIT_SPELL" },
    dodge = { 12, "CR_DODGE" }, parry = { 15, "CR_PARRY" }, block = { 5, "CR_BLOCK" },
}
-- One crit / hit rating counts for melee and spells on Forever (SimGear
-- Forever Stats.EXPANDS; item 272457, a caster hood with "critical strike").
local POOLED = { crit = "spellCrit", hit = "spellHit" }

function Stats.Percent(key, value)
    local r = RATINGS[key]
    if not r then return value end
    local fn, index = _G["GetCombatRatingBonusForCombatRatingValue"], _G[r[2]]
    if type(fn) == "function" and type(index) == "number" then
        local ok, pct = pcall(fn, index, value)
        if ok and type(pct) == "number" and not (issecretvalue and issecretvalue(pct)) and pct > 0 then return pct end
    end
    return value / r[1]
end

Stats.API_KEYS = API_KEYS
Stats.KEYS = {}
for _, key in pairs(API_KEYS) do Stats.KEYS[key] = true end
Stats.KEYS.spellPower = nil  -- split into spellDmg + heal
Stats.KEYS.dps = nil         -- lives in item.weapon
Stats.KEYS.procDps = true    -- expected damage of "chance on hit" procs (Effects.lua)
-- spell damage of one school (Effects.lua: equip lines GetItemStats lacks)
for _, school in ipairs({ "holy", "fire", "nature", "frost", "shadow", "arcane" }) do
    Stats.KEYS[school .. "Dmg"] = true
end

-- How often a damage proc fires: the item's own rate when the server data has
-- one (Data/ItemProcs.lua, generated from cMaNGOS), else about once per
-- minute - assumption: Classic weapon procs mostly sit near 1 per minute, the
-- tooltip does not say; shown as estimated.
Stats.PROCS_PER_MINUTE = 1
local DEFAULT_SPEED = 2.5  -- assumption: swing speed for a chance per hit on a non-weapon

function Stats.ProcsPerMinute(item)
    local id = tonumber(item.link and item.link:match("item:(%d+)"))
    local known = id and ns.ItemProcs and ns.ItemProcs[id]
    if not known then return Stats.PROCS_PER_MINUTE, false end
    if known[1] > 0 then return known[1], true end
    local speed = item.weapon and item.weapon.speed or DEFAULT_SPEED
    return known[2] / 100 * 60 / speed, true
end

-- Equip-effect green (00ff00) and the quality green of item names (1eff00).
local GREEN = { ["00ff00"] = true, ["1eff00"] = true }
local RED = "ff2020"  -- RED_FONT_COLOR (1, 0.125, 0.125)

local function ColorHex(c)
    if type(c) ~= "table" or type(c.r) ~= "number" then return nil end
    local function byte(x) return math.floor(x * 255 + 0.5) end
    return ("%02x%02x%02x"):format(byte(c.r), byte(c.g), byte(c.b))
end

local function Num(s)
    return tonumber((s:gsub(",", ".")))
end

local function Numbers(text)
    local out = {}
    for n in text:gmatch("%d+[,.]?%d*") do out[#out + 1] = Num(n) end
    return out
end
Stats.Numbers = Numbers

local function ApiStats(link)
    local ok, raw = pcall(C_Item.GetItemStats, link)
    local stats, claimable = {}, {}
    if not ok or type(raw) ~= "table" then return stats, claimable end
    for apiKey, value in pairs(raw) do
        local key = API_KEYS[apiKey]
        if SAME_AS[apiKey] and raw[SAME_AS[apiKey]] then key = nil end
        if key and type(value) == "number" then
            value = Stats.Percent(key, value)
            if key == "spellPower" then
                stats.spellDmg = (stats.spellDmg or 0) + value
                stats.heal = (stats.heal or 0) + value
            else
                stats[key] = (stats[key] or 0) + value
                if POOLED[key] then stats[POOLED[key]] = (stats[POOLED[key]] or 0) + value end
            end
            if key ~= "dps" and key ~= "armor" then
                claimable[#claimable + 1] = { value = value, key = key }
            end
        end
    end
    return stats, claimable
end

local function Claim(claimable, text)
    for _, n in ipairs(Numbers(text)) do
        for _, c in ipairs(claimable) do
            if not c.claimed and c.value == n then
                c.claimed = true
                return true
            end
        end
    end
    return false
end

-- Weapon damage "64 - 97 Schaden" (any language: first "a - b" line) and
-- speed on the right of that line ("Tempo 2,90" / "Speed 2.90").
local function ReadWeapon(lines, item)
    for _, line in ipairs(lines) do
        local left = type(line.leftText) == "string" and line.leftText or ""
        local lo, hi = left:match("^(%d+) %- (%d+)")
        if lo then
            local speed = type(line.rightText) == "string" and line.rightText:match("(%d+[,.]%d+)")
            item.weapon = {
                min = tonumber(lo), max = tonumber(hi), speed = speed and Num(speed) or nil,
                twoHand = item.equipLoc == "INVTYPE_2HWEAPON",
                dagger = item.subclassID == 15,  -- Enum.ItemWeaponSubclass.Dagger (Backstab)
                ranged = item.equipLoc == "INVTYPE_RANGED" or item.equipLoc == "INVTYPE_RANGEDRIGHT"
                    or item.equipLoc == "INVTYPE_THROWN",
            }
            return
        end
    end
end

local function ApplyEffect(item, e)
    if e.kind == "stat" then
        item.stats[e.key] = (item.stats[e.key] or 0) + e.value
    elseif e.kind == "weaponDamage" then
        item.weaponBonus = (item.weaponBonus or 0) + e.value
    elseif e.kind == "proc" then
        local ppm, known = Stats.ProcsPerMinute(item)
        item.procPpm, item.procKnown = ppm, known
        local perMinute = (e.min + e.max) / 2 * ppm
        item.stats.procDps = (item.stats.procDps or 0) + perMinute / 60
    end
end

local function ReadTooltip(link, item, claimable)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return end
    if item.classID == 2 then ReadWeapon(data.lines, item) end
    -- White base stat lines ("+10 Beweglichkeit") claim their values first, so
    -- a green line with the same number ("... um zusätzliche 10%") cannot.
    local green = {}
    for i, line in ipairs(data.lines) do
        local text = line.leftText
        for _, side in ipairs({ { line.leftText, line.leftColor }, { line.rightText, line.rightColor } }) do
            if i > 1 and type(side[1]) == "string" and side[1] ~= "" and ColorHex(side[2]) == RED then
                item.red[#item.red + 1] = side[1]
            end
        end
        if i > 1 and type(text) == "string" and text ~= "" then
            if GREEN[ColorHex(line.leftColor) or ""] then
                green[#green + 1] = text
            elseif text:match("^[+-]%d") then
                Claim(claimable, text)
            end
        end
    end
    for _, text in ipairs(green) do
        local school = ns.Effects.School(text)
        local known
        for _, c in ipairs(school and claimable or {}) do
            if not c.claimed and c.key == school.key and c.value == school.value then
                c.claimed, known = true, true
                break
            end
        end
        if known then
            item.effects[#item.effects + 1] = text  -- already counted from GetItemStats
        elseif school then
            -- exact client text of one school's spell damage; should the client
            -- ever count it as general spell damage too, that part is taken back
            for _, c in ipairs(claimable) do
                if not c.claimed and c.value == school.value and (c.key == "spellDmg" or c.key == "spellPower") then
                    c.claimed = true
                    item.stats.spellDmg = (item.stats.spellDmg or 0) - c.value
                    if c.key == "spellPower" then item.stats.heal = (item.stats.heal or 0) - c.value end
                    break
                end
            end
            ApplyEffect(item, school)
            item.effects[#item.effects + 1] = text
        elseif not Claim(claimable, text) then
            local effect = ns.Effects.Parse(text)
            if effect then
                ApplyEffect(item, effect)
                item.effects[#item.effects + 1] = text
            else
                item.unrated[#item.unrated + 1] = text
            end
        end
    end
end

local cache = {}

function Stats.Read(link)
    if type(link) ~= "string" then return nil end
    if cache[link] then return cache[link] end
    local name, _, quality, level, minLevel, _, _, _, equipLoc, icon, _, classID, subclassID = C_Item.GetItemInfo(link)
    if not name then return nil end

    local stats, claimable = ApiStats(link)
    local item = {
        name = name, link = link, quality = quality, level = level, minLevel = minLevel or 0,
        equipLoc = equipLoc, icon = icon, classID = classID, subclassID = subclassID,
        stats = stats, unrated = {}, effects = {}, red = {},
    }
    ReadTooltip(link, item, claimable)
    local w = item.weapon
    if w then
        w.dps = stats.dps or (w.speed and (w.min + w.max) / 2 / w.speed)
        local bonus = item.weaponBonus or 0  -- enchant: flat damage on every hit
        w.min, w.max = w.min + bonus, w.max + bonus
        if w.dps and w.speed then w.dps = w.dps + bonus / w.speed end
    end
    stats.dps = nil
    cache[link] = item
    return item
end

function Stats.ClearCache()
    cache = {}
end

-- Item links in any client format (|cff...| and the newer |cnIQ3:|).
function Stats.Links(text)
    local out = {}
    for link in (text or ""):gmatch("|c[^|]*|Hitem:.-|h.-|h|r") do out[#out + 1] = link end
    return out
end
