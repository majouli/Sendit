--[[
  Model: Classic combat formulas as expected values (no random rolls, no
  rotation). Every function takes a character snapshot (Character.lua) and
  returns a number; specs (Specs/*.lua) combine them into their metrics.

  Sources and confidence of every constant are noted next to it. The target is
  a normal mob of the player's level fought from the front - the leveling case
  (its armor: Mobs.lua).
]]
local _, ns = ...

local Model = {}
ns.Model = Model

-- Attack table against a mob of equal level, in percent (the standard target;
-- the player can pick a higher one: Model.Target).
Model.TARGET = {
    miss = 5,             -- warcraft.wiki.gg "Hit": 5% base miss vs equal level (single wield)
    dodge = 5,            -- assumption: mobs of equal level dodge ~5% (Classic theorycraft)
    parry = 5,            -- assumption: ~5% parry when attacking from the front
    glance = 10,          -- assumption: 10% glancing blows vs equal level
    glancePenalty = 0.05, -- assumption: glancing blows deal 5% less at equal weapon skill
    dualWieldMiss = 19,   -- warcraft.wiki.gg "Dual wield" (Classic): +19% miss while dual wielding
    rangedDodge = 5,      -- assumption: ranged attacks can be dodged like melee, never parried
}
Model.OFFHAND = 0.5       -- warcraft.wiki.gg "Dual wield": the off hand deals 50% (before talents)
-- Instant weapon abilities add attack power at a normalized weapon speed
-- (warcraft.wiki.gg "Normalization"): daggers 1.7, other one-handers 2.4,
-- two-handers 3.3, ranged 2.8. The client data marks them as normalized
-- weapon damage (effect 121).
Model.NORMALIZED = { dagger = 1.7, oneHand = 2.4, twoHand = 3.3, ranged = 2.8 }
Model.SPELL_CRIT_DAMAGE = 0.5 -- spell crits deal 150% (Classic, before talents)
Model.AP_PER_DPS = 14     -- warcraft.wiki.gg "Attack power": 14 AP = 1 weapon DPS (Classic)
Model.CRIT_MULT = 2       -- melee crits deal 200%
Model.SPELL_CRIT_HEAL = 0.5 -- heals crit for 150%
Model.BASE_MISS_ON_YOU = 5 -- equal-level mobs miss you 5% (same table as above)
Model.UNARMED = { min = 1, max = 2, speed = 2.0 } -- assumption: unarmed damage, only for "empty slot"
Model.SPELL_HIT = 96      -- warcraft.wiki.gg "Spell hit" (Classic): 4% spell miss vs equal level
Model.SPELL_HIT_CAP = 99  -- same page: spells always have at least 1% miss
-- Higher targets (the page's "Enemy level": +0 standard ... +3), index = levels above + 1.
Model.MISS_BY_DELTA = { 5, 5.5, 6, 8 }         -- warcraft.wiki.gg "Hit" (Classic): white miss, single wield
Model.SPELL_HIT_BY_DELTA = { 96, 95, 94, 83 }  -- warcraft.wiki.gg "Spell hit" (Classic): 4 / 5 / 6 / 17 % miss
Model.AVOID_PER_LEVEL = 0.5 -- Classic: dodge / parry +0.1% per defense point over the weapon skill, 5 per level
-- Glancing blows: chance and damage penalty are SEPARATE parameters, both by
-- level difference (index = levels above + 1). Chance: Forever's provisional
-- 30% at +2 (Classic rule 10% + 10% per level); penalty: Classic figures
-- (warcraft.wiki.gg "Glancing blow"), NOT confirmed for Forever - Blizzard's
-- beta known issues call the penalty vs higher targets wrong. White miss at +2:
-- 6% is the Classic figure; a Forever client read gives 5.4% - unconfirmed,
-- kept at the Classic value until live combat logs settle it.
Model.GLANCE_BY_DELTA = { 10, 20, 30, 40 }
Model.GLANCE_PENALTY_BY_DELTA = { 0.05, 0.05, 0.15, 0.35 }

-- How many levels above the character the target is (s.targetLevel, 0..3).
function Model.Delta(s)
    return math.max(0, math.min(3, (s.targetLevel or s.level or 0) - (s.level or 0)))
end

function Model.TargetLevel(s)
    return (s.level or 1) + Model.Delta(s)
end

-- The attack table against the chosen target.
function Model.Target(s)
    local d = Model.Delta(s)
    if d == 0 then return Model.TARGET end
    local base, avoid = Model.TARGET, Model.AVOID_PER_LEVEL * d
    return setmetatable({ miss = Model.MISS_BY_DELTA[d + 1], dodge = base.dodge + avoid, parry = base.parry + avoid,
        rangedDodge = base.rangedDodge + avoid, glance = Model.GLANCE_BY_DELTA[d + 1],
        glancePenalty = Model.GLANCE_PENALTY_BY_DELTA[d + 1] }, { __index = base })
end

-- Armor damage reduction vs an attacker of the given level.
-- warcraft.wiki.gg "Armor" (Classic): armor / (armor + 400 + 85 * level)
function Model.ArmorReduction(armor, level)
    if armor <= 0 then return 0 end
    return armor / (armor + 400 + 85 * level)
end

-- Share of physical damage left after the target mob's armor.
function Model.TargetArmorFactor(s)
    return 1 - Model.ArmorReduction(ns.Mobs.Armor(Model.TargetLevel(s)), s.level)
end

-- Share of spells (and spell procs) that hit the target.
function Model.SpellLanded(s)
    local d = Model.Delta(s)
    local base = d == 0 and Model.SPELL_HIT or Model.SPELL_HIT_BY_DELTA[d + 1]
    return math.min(Model.SPELL_HIT_CAP, base + (s.spellHit or 0)) / 100
end

-- Melee white damage per second of one weapon (after the mob's armor) and
-- the share of swings that land. extraMiss: the dual wield penalty.
local function Swing(s, w, extraMiss)
    local t = Model.Target(s)
    local miss = math.max(0, t.miss + (extraMiss or 0) - (s.hit or 0)) / 100
    local landed = math.max(0, 1 - miss - t.dodge / 100 - t.parry / 100)
    local glance = math.min(t.glance / 100, landed)
    local crit = math.max(0, math.min((s.crit or 0) / 100, landed - glance))
    local normal = landed - glance - crit
    local swing = (w.min + w.max) / 2 + s.ap / Model.AP_PER_DPS * w.speed
    local perSwing = normal + Model.CRIT_MULT * crit + glance * (1 - t.glancePenalty)
    return swing / w.speed * perSwing * Model.TargetArmorFactor(s), landed
end

-- The main hand alone (Paladin, Shaman, two-handers); single wield - no
-- dual wield miss. Model.MainHandDps: the main hand as it swings now (with
-- the dual wield miss while an off-hand weapon is worn: Windfury's attacks).
function Model.WhiteDps(s)
    return Swing(s, s.weapon or Model.UNARMED, 0)
end

function Model.MainHandDps(s)
    return Swing(s, s.weapon or Model.UNARMED, s.offWeapon and Model.TARGET.dualWieldMiss or 0)
end

-- Both hands: with an off-hand weapon both swing with the dual wield miss
-- penalty, the off hand at `offhand` (default Model.OFFHAND) of its damage.
-- Also returns the share of swings that crit (Flurry, Deep Wounds).
-- offhandHit: talents that add hit to the off hand only (Furious Precision).
function Model.MeleeDps(s, offhand, offhandHit)
    if not s.offWeapon then
        local dps, landed = Model.WhiteDps(s)
        return dps, landed
    end
    local main, landed = Swing(s, s.weapon or Model.UNARMED, Model.TARGET.dualWieldMiss)
    local off = Swing(s, s.offWeapon, Model.TARGET.dualWieldMiss - (offhandHit or 0))
    return main + (offhand or Model.OFFHAND) * off, landed
end

-- Share of yellow (ability) attacks that land, and their crit share: the
-- attack table without the dual wield penalty and without glancing blows.
-- yellow: special attacks roll crit only on a hit (two-roll table, Classic -
-- warcraft.wiki.gg "Attack table"; Forever unconfirmed): crit share = landed *
-- crit, so hit also adds crits. White attacks (auto shot) roll once.
function Model.Special(s, ranged, yellow)
    local t = Model.Target(s)
    local miss = math.max(0, t.miss - ((ranged and s.rangedHit or s.hit) or 0)) / 100
    local avoid = ranged and t.rangedDodge / 100 or (t.dodge + t.parry) / 100
    local landed = math.max(0, 1 - miss - avoid)
    local chance = math.max(0, (ranged and s.rangedCrit or s.crit or 0) / 100)
    local crit = yellow and landed * math.min(chance, 1) or math.min(chance, landed)
    return landed, crit
end

-- One hit of a weapon ability (Spells.Get part `weapon`): pct % of the weapon's
-- average damage plus attack power at the normalized speed, plus the flat bonus.
function Model.WeaponHit(s, weapon, part, ranged)
    local w = weapon or Model.UNARMED
    local speed = (w.paw and w.speed) or ranged and Model.NORMALIZED.ranged or (w.dagger and Model.NORMALIZED.dagger)
        or (w.twoHand and Model.NORMALIZED.twoHand) or Model.NORMALIZED.oneHand
    local ap = ranged and (s.rap or 0) or s.ap
    local ammo = ranged and (s.ammoDps or 0) * w.speed or 0
    return ((w.min + w.max) / 2 + (w.bonus or 0) + ammo + ap / Model.AP_PER_DPS * speed) * part.pct / 100 + part.flat
end

-- Ranged auto shot per second: ranged weapon, ammo (s.ammoDps: arrows add
-- damage per second of the weapon's speed), ranged attack power and crit;
-- no glancing, no parry. critMult: talents (Mortal Shots) raise it.
function Model.RangedDps(s, critMult)
    local w = s.rangedWeapon
    if not w then return 0 end
    local landed, crit = Model.Special(s, true)
    local shot = (w.min + w.max) / 2 + ((s.ammoDps or 0) + (s.rap or 0) / Model.AP_PER_DPS) * w.speed
    return shot / w.speed * (landed - crit + (critMult or Model.CRIT_MULT) * crit) * Model.TargetArmorFactor(s)
end

-- One cast of a spell (Spells.Get) with this much spell power and crit (%):
-- the direct part can crit (critBonus: 0.5 = 150%, talents raise it); periodic
-- damage crits too on Forever (Classic: never - critical ticks seen in
-- game 2026-11-17), at the base 150%: talents that raise crit damage are
-- assumed to touch the direct part only; healing over time is assumed not to
-- crit. dotCritBonus: talents that raise the ticks' crit damage (Pandemic,
-- Shadowform: 1.0 = 200%). Damage only counts the share that hits.
function Model.Cast(s, sp, power, crit, damage, critBonus, dotCritBonus)
    local amount = 0
    if sp.direct then
        local bonus = critBonus or (damage and Model.SPELL_CRIT_DAMAGE or Model.SPELL_CRIT_HEAL)
        amount = (sp.direct.avg + sp.direct.coef * power) * (1 + bonus * math.min(1, math.max(0, crit) / 100))
    end
    if sp.dot then
        local dotCrit = damage and (dotCritBonus or Model.SPELL_CRIT_DAMAGE) * math.min(1, math.max(0, crit) / 100) or 0
        amount = amount + (sp.dot.total + sp.dot.coef * power) * (1 + dotCrit)
    end
    if sp.absorb then amount = amount + sp.absorb.amount + sp.absorb.coef * power end
    if damage then amount = amount * Model.SpellLanded(s) end
    return amount
end

-- Share of a hit a block stops: the block value against the mob's hit after
-- armor (Mobs.Hit, an estimate), at most all of it.
function Model.BlockShare(s, reduction)
    local hit = ns.Mobs.Hit(Model.TargetLevel(s)) * (1 - reduction)
    if hit <= 0 then return 0 end
    return math.min(1, (s.blockValue or 0) / hit)
end

-- Share of an equal-level mob's raw melee damage that reaches the character.
function Model.Mitigation(s)
    local reduction = Model.ArmorReduction(s.armor, s.level)
    local avoid = (Model.BASE_MISS_ON_YOU + s.dodge + s.parry + (s.defMiss or 0)
        + Model.BlockShare(s, reduction) * s.block) / 100
    avoid = math.min(0.75, math.max(0, avoid))
    return (1 - reduction) * (1 - avoid)
end

-- Effective health: how much raw damage it takes to kill the character.
function Model.Survival(s)
    return s.hp / Model.Mitigation(s)
end

-- The leveling cycle of a caster or healer, one pull after the other: fight
-- (casting all the time), rest until the next pull - spirit regenerates once
-- 5 s have passed since the last cast - and drink back to full once the mana
-- is below half. Output per second of fighting and drinking; the walk to the
-- next mob is the same whatever the gear, so it is not counted - but the
-- spirit regen during it is. A fight of fixed length with no refill made
-- every point of mana count as fully as a point of output (+10 intellect
-- worth ten times +10 healing); "cast until OOM, then one break" made the bar
-- size the bottleneck. Here, as in play: spirit and mana per 5 refill between
-- pulls, spell power ends fights sooner (less mana per kill), and a bigger
-- bar mostly means fewer drink sessions - drinking itself refills at the
-- drink's fixed rate. The same reference scenario SimGear Forever sims
-- (40 s between pulls, drink below 50 %), here as an expected-value formula.
Model.PULL_GAP = 40       -- assumption: seconds between two pulls (walk, loot; SimGear Forever's leveling reference)
Model.FIVE_SECOND_RULE = 5 -- warcraft.wiki.gg "Five second rule": spirit regen pauses 5 s after a cast
Model.DRINK_BELOW = 0.5   -- assumption: drink once the bar is below half (SimGear Forever's reference)
Model.DRINK_SESSION = 5   -- assumption: seconds lost per drink session (sit down, start, stand up)
Model.HEAL_FIGHT = 20     -- assumption: seconds a healer heals per pull (a group pull)
-- Mana per 2 s tick out of combat (warcraft.wiki.gg "Spirit", Classic):
-- base + spirit / per. Forever unverified: GetManaRegen() shows the live value.
Model.SPIRIT_REGEN = {
    PRIEST = { 13, 4 }, MAGE = { 13, 4 }, WARLOCK = { 8, 4 },
    DRUID = { 15, 5 }, HUNTER = { 15, 5 }, PALADIN = { 15, 5 }, SHAMAN = { 17, 5 },
}

-- Mana per second from spirit out of the five second rule.
function Model.SpiritRegen(s)
    local r = Model.SPIRIT_REGEN[s.class]
    if not r then return 0 end
    return math.max(0, r[1] + (s.spi or 0) / r[2]) / 2
end

-- Output per second of the cycle, from output and mana per second of casting;
-- healing: the fight lasts HEAL_FIGHT instead of until the mob is dead.
function Model.Sustained(s, rate, manaPerSec, healing)
    local pool = s.mana or 0
    if rate <= 0 or pool <= 0 then return rate end
    local mp5 = (s.mp5 or 0) / 5
    local fight = healing and Model.HEAL_FIGHT or ns.Mobs.Health(Model.TargetLevel(s)) / rate
    local spent = (manaPerSec - mp5) * fight
    local spirit = Model.SpiritRegen(s)
    local rest = (spirit + mp5) * math.max(0, Model.PULL_GAP - Model.FIVE_SECOND_RULE) + mp5 * Model.FIVE_SECOND_RULE
    local net = spent - rest
    if net <= 0 then return rate end
    local drinkRate = ns.Mobs.Drink(s.level) + spirit + mp5
    -- a session starts below DRINK_BELOW and refills to full: on average half a pull's net above it
    local refill = math.min(pool, pool * (1 - Model.DRINK_BELOW) + net / 2)
    local drinking = net / drinkRate + Model.DRINK_SESSION * net / refill
    return rate * fight / (fight + drinking)
end
