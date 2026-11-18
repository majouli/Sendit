--[[
  Common: the building blocks every class file makes its talent trees from.

  A metric = { label (localized, read when shown), unit, fn(snapshot) -> number }.
  Compare.lua turns the difference of two snapshots into percent, so constant
  factors (talents that add a flat %, stances, buffs) cancel out. What a tree
  changes is HOW a stat moves the number - and that is what the blocks model:
  which spells or attacks it uses, how often, and the talents that change the
  worth of a stat (crit damage, off-hand damage, Flurry, stat multipliers).
  Talents cannot be read on this client: every tree assumes its standard
  build, named where it is used (warcraft.wiki.gg talent pages, Classic).

    Common.Metric(textKey, unit, fn)
    Common.Caster{ dots, cds, filler, critBonus, dotCritBonus, castDelta, instant, lifeTap,
                   critVuln, critHaste }
        critVuln = { key, pct, dur }: a crit of that filler spell makes the target
          take pct more from it for dur s (Improved Shadow Bolt); uptime =
          chance that one of the casts in dur s landed a crit
        critHaste = { pct, dur }: a non-periodic crit hastes casting by pct for
          dur s (Nature's Grace); the filler casts faster by pct * uptime
        spell damage per second of the leveling cycle (Model.Sustained): damage
        over time kept up, cooldown spells on cooldown, the best filler in the
        rest - the filler that gives the most once drink breaks are counted;
        lifeTap: no drinking (Warlocks turn health into mana, eaten back)
    Common.Healer{ big, fast, shield, spiritToHeal, castDelta, critRefund }
        HPS of the same cycle: Power Word: Shield on its 15 s Weakened Soul,
        then the big or the fast heal, whichever heals more per cycle second;
        critRefund = share of a heal's mana a crit gives back (Illumination)
    castDelta = { SPELL_KEY = -0.5 }: talents that shorten a cast (Improved
        Frostbolt ...), never below the global cooldown
    Common.Melee{ offhand, offhandHit, flurry, abilityCrit, deepWounds, builder, cds, apAbility, rageDump }
        white damage of both hands (+ Flurry haste) plus weapon abilities:
        cooldown abilities on cooldown, the builder from the energy left over,
        the rage dump (Heroic Strike) from the rage left over
    Common.Ranged{ shots, critMult }   auto shot plus shots on cooldown, stings kept up
    Common.Survival                    effective health
    Common.FromIntellect(fn, { { level, ap, rap, spellDmg }, ... })
        Forever talents that turn intellect into attack power / spell damage
        (share of intellect each); only the change from the live intellect
        counts - the live values already hold the live share
  statMult on a spec ({ agi = 1.15 }): talents that multiply a stat; applied to
  the item stats being compared (Compare.lua) - live stats already have them.
]]
local _, ns = ...
local L = ns.L
local Model, Character = ns.Model, ns.Character

local Common = {}
ns.SpecCommon = Common

local GCD = 1.5
local ENERGY_PER_SEC = 10       -- Classic energy regeneration
local ENERGY_FOR_BUILDERS = 0.6 -- assumption: the rest feeds finishers (no gear scaling in Classic)
local WEAKENED_SOUL = 15        -- Power Word: Shield again on the same target after 15 s

-- metric.label is read when shown, so it follows a language switch.
function Common.Metric(textKey, unit, fn)
    return setmetatable({ unit = unit, fn = fn }, { __index = function(_, k)
        if k == "label" then return L[textKey] end
    end })
end

local function Procs(s)
    return (s.procDps or 0) * Model.SpellLanded(s)
end

---------------------------------------------------------------------------
-- Casters
---------------------------------------------------------------------------
local function CastTime(sp, key, o)
    if o.instant and o.instant[key] then return GCD end
    return math.max(GCD, sp.time + (o.castDelta and o.castDelta[key] or 0))
end

local function Damage(s, sp, o)
    local power = Character.SpellPower(s, sp.school)
    return Model.Cast(s, sp, power, Character.SpellCrit(s, sp.school), true, o.critBonus, o.dotCritBonus)
end

-- Per second of casting: share of the time used, damage (or healing), mana.
-- noDrink: the class turns health into mana (Life Tap) instead of drinking.
local function Rotation(healing, noDrink)
    local r = { used = 0, amount = 0, mana = 0 }
    function r.Add(perSec, time, amount, cost)
        r.used = r.used + perSec * time
        r.amount = r.amount + perSec * amount
        r.mana = r.mana + perSec * cost
    end
    -- more than the whole time planned (many dots at a low level): scale down
    function r.Fit()
        if r.used > 1 then r.amount, r.mana, r.used = r.amount / r.used, r.mana / r.used, 1 end
    end
    -- the best spell to fill the time left, rated over the whole cycle
    function r.Best(s, candidates)
        local function Cycle(amount, mana)
            if noDrink then return amount end
            return Model.Sustained(s, amount, mana, healing)
        end
        local best = Cycle(r.amount, r.mana)
        for _, c in ipairs(candidates) do
            local perSec = (1 - r.used) / c.time
            best = math.max(best, Cycle(r.amount + perSec * c.amount, r.mana + perSec * c.cost))
        end
        return best
    end
    return r
end

function Common.Caster(o)
    return function(s)
        local r = Rotation(false, o.lifeTap)
        -- damage over time: one cast per duration, kept up
        for _, key in ipairs(o.dots or {}) do
            local sp = ns.Spells.Get(key, s.level)
            if sp and sp.dur > 0 then r.Add(1 / sp.dur, CastTime(sp, key, o), Damage(s, sp, o), sp.cost) end
        end
        -- cooldown spells: as often as the cooldown allows
        for _, key in ipairs(o.cds or {}) do
            local sp = ns.Spells.Get(key, s.level)
            if sp then
                local t = CastTime(sp, key, o)
                r.Add(1 / math.max(sp.cd, t), t, Damage(s, sp, o), sp.cost)
            end
        end
        r.Fit()
        local fillers = {}
        for _, key in ipairs(o.filler or {}) do
            local sp = ns.Spells.Get(key, s.level)
            if sp then
                local time, amount = CastTime(sp, key, o), Damage(s, sp, o)
                local crit = math.min(1, math.max(0, Character.SpellCrit(s, sp.school)) / 100) * Model.SpellLanded(s)
                local function Uptime(dur, t) return 1 - (1 - crit) ^ math.max(1, dur / t) end
                if o.critHaste then
                    time = math.max(GCD * (1 - o.critHaste.pct), time / (1 + o.critHaste.pct * Uptime(o.critHaste.dur, time)))
                end
                if o.critVuln and o.critVuln.key == key then
                    -- casting only this filler in the time left: its casts within dur s
                    local t = time / math.max(0.01, 1 - r.used)
                    amount = amount * (1 + o.critVuln.pct * Uptime(o.critVuln.dur, t))
                end
                fillers[#fillers + 1] = { time = time, amount = amount, cost = sp.cost }
            end
        end
        return r.Best(s, fillers) + Procs(s)
    end
end

---------------------------------------------------------------------------
-- Healers
---------------------------------------------------------------------------
local function Heal(s, sp, o)
    o = o or {}
    local power = (s.heal or 0) + (s.spiritHeal or 0)
    local crit = Character.SpellCrit(s, sp.school)
    local refund = sp.direct and (o.critRefund or 0) * math.min(1, math.max(0, crit) / 100) or 0
    return { amount = Model.Cast(s, sp, power, crit, false), cost = sp.cost * (1 - refund),
             time = CastTime(sp, sp.key, o) }
end

function Common.Healer(o)
    return function(s)
        if o.spiritToHeal then
            s = setmetatable({ spiritHeal = (s.spi or 0) * o.spiritToHeal }, { __index = s })
        end
        local r = Rotation(true)
        local shield = o.shield and ns.Spells.Get(o.shield, s.level)
        if shield then
            local h = Heal(s, shield, o)
            r.Add(1 / math.max(WEAKENED_SOUL, shield.cd), h.time, h.amount, h.cost)
        end
        local heals = {}
        local big = o.big and ns.Spells.Best(o.big, s.level)
        local fast = o.fast and ns.Spells.Best(o.fast, s.level)
        if big then heals[#heals + 1] = Heal(s, big, o) end
        if fast then heals[#heals + 1] = Heal(s, fast, o) end
        return r.Best(s, heals)
    end
end

---------------------------------------------------------------------------
-- Melee
---------------------------------------------------------------------------
-- One use of an ability: weapon abilities, a share of attack power
-- (Bloodthirst), flat school damage (Arcane Shot: rolls on the attack table,
-- crits like a weapon hit) or damage over time (Serpent Sting: needs to land,
-- cannot crit). Armor only stops physical damage.
local function Ability(s, sp, o, ranged)
    local landed, crit = Model.Special(s, ranged, true)
    local armor = sp.school == "physical" and Model.TargetArmorFactor(s) or 1
    local hit
    if o.apAbility and sp.dummy then
        hit = s.ap * sp.dummy / 100  -- Bloodthirst: a share of attack power (client data: 45)
    elseif sp.weapon then
        hit = Model.WeaponHit(s, ranged and s.rangedWeapon or s.weapon, sp.weapon, ranged)
    elseif sp.direct then
        hit = sp.direct.avg + sp.direct.coef * Character.SpellPower(s, sp.school)
    elseif sp.dot then
        return (sp.dot.total + sp.dot.coef * Character.SpellPower(s, sp.school)) * landed * armor
    else
        return 0
    end
    hit = hit * (o.abilityBonus or 1)
    local critMult = (ranged and o.critMult) or o.abilityCrit or Model.CRIT_MULT
    return hit * (landed - crit + critMult * crit) * armor
end

-- Damage per second of an ability used on cooldown (nil: not known yet).
function Common.OnCooldown(s, key, o)
    local sp = ns.Spells.Get(key, s.level)
    if not sp or sp.cd <= 0 then return 0 end
    return Ability(s, sp, o or {}) / sp.cd
end

-- Rage from dealing damage, Classic (warcraft.wiki.gg "Rage"): 7.5 * damage / c,
-- c = 0.0091107836 * level^2 + 3.225598133 * level + 4.2652911 (rage, not the
-- client's tenths: the client data stores ability costs * 10).
local function RagePerDamage(level)
    return 7.5 / (0.0091107836 * level * level + 3.225598133 * level + 4.2652911)
end
Common.RagePerDamage = RagePerDamage

-- The rage dump (Heroic Strike): white swings bring the rage, the cooldown
-- abilities take theirs first, the rest turns swings into the dump. Each use
-- adds its flat bonus over the swing it replaces, as a yellow hit (no glancing).
-- Assumption: the rage the replaced swing would have brought is left out.
local function RageDump(s, o, white, cdRage)
    local sp = ns.Spells.Get(o.rageDump, s.level)
    local w = s.weapon or Model.UNARMED
    if not sp or not sp.weapon or sp.cost <= 0 then return 0 end
    local spare = white * RagePerDamage(s.level) - cdRage
    if spare <= 0 then return 0 end
    local perSec = math.min(spare / (sp.cost / 10), 1 / w.speed)
    local landed, crit = Model.Special(s, false, true)
    local critMult = o.abilityCrit or Model.CRIT_MULT
    return perSec * sp.weapon.flat * (landed - crit + critMult * crit) * Model.TargetArmorFactor(s)
end

function Common.Melee(o)
    o = o or {}
    return function(s)
        local white, landed = Model.MeleeDps(s, o.offhand, o.offhandHit)
        local crit = math.min((s.crit or 0) / 100, landed)
        if o.flurry then
            -- Flurry: a crit hastes the next 3 swings; up while one of the last 3 swings crit
            white = white * (1 + o.flurry * (1 - (1 - crit) ^ 3))
        end
        -- cooldown abilities; rage ones only as often as the rage from white
        -- damage pays for (a leveling warrior starts each fight at 0 rage)
        local rageAbilities, otherAbilities, cdRage = 0, 0, 0
        for _, key in ipairs(o.cds or {}) do
            local sp = ns.Spells.Get(key, s.level)
            if sp and sp.cd > 0 then
                if sp.power == "rage" and sp.cost > 0 then
                    rageAbilities = rageAbilities + Ability(s, sp, o) / sp.cd
                    cdRage = cdRage + sp.cost / 10 / sp.cd
                else
                    otherAbilities = otherAbilities + Ability(s, sp, o) / sp.cd
                end
            end
        end
        local rage = white * RagePerDamage(s.level)
        local abilities = otherAbilities + rageAbilities * (cdRage > 0 and math.min(1, rage / cdRage) or 1)
        if o.rageDump then abilities = abilities + RageDump(s, o, white, cdRage) end
        local b = o.builder and o.builder(s)
        if b then
            local sp = ns.Spells.Get(b.key, s.level)
            if sp then
                local cost = b.cost or sp.cost
                if cost > 0 then
                    abilities = abilities + Ability(s, sp, o) * ENERGY_PER_SEC * ENERGY_FOR_BUILDERS / cost
                end
            end
        end
        local total = white + abilities
        if o.deepWounds then total = total * (1 + o.deepWounds * crit) end
        return total + Procs(s)
    end
end

function Common.Ranged(o)
    o = o or {}
    return function(s)
        local total = Model.RangedDps(s, o.critMult)
        for _, key in ipairs(o.shots or {}) do
            local sp = ns.Spells.Get(key, s.level)
            local every = sp and (sp.dot and sp.dur or sp.cd) or 0  -- a sting kept up
            if every > 0 then total = total + Ability(s, sp, o, true) / every end
        end
        return total + Procs(s)
    end
end

Common.Survival = Model.Survival
Common.SURVIVAL = Common.Metric("survival", "EHP", Common.Survival)

-- Intellect into attack power / spell damage (Forever talents, see the header).
function Common.FromIntellect(fn, convs)
    return function(s)
        local delta = (s.int or 0) - (s.liveInt or s.int or 0)
        if delta == 0 then return fn(s) end
        local f = setmetatable({}, { __index = s })
        for _, c in ipairs(convs) do
            if s.level >= c.level then
                if c.ap then f.ap = (f.ap or 0) + c.ap * delta end
                if c.rap then f.rap = (f.rap or 0) + c.rap * delta end
                if c.spellDmg then f.spellDmg = (f.spellDmg or 0) + c.spellDmg * delta end
            end
        end
        return fn(f)
    end
end

-- Gear sums and shapes for the spec guesses.
function Common.Sum(gear, key)
    local n = 0
    for _, item in pairs(gear) do n = n + (item.stats[key] or 0) end
    return n
end

function Common.HasShield(gear)
    return gear[17] ~= nil and gear[17].equipLoc == "INVTYPE_SHIELD"
end

function Common.DualWields(gear)
    return gear[17] ~= nil and gear[17].weapon ~= nil
end

function Common.MainDagger(gear)
    return gear[16] ~= nil and gear[16].weapon ~= nil and gear[16].weapon.dagger == true
end
