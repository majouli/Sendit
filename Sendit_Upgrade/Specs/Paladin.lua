--[[
  Paladin: the three specs as metrics on a character snapshot.
    RET   primary damage (DPS), secondary survival; Seal of Command (the
          standard Retribution talent, from level 20) - a slow weapon hits
          harder with it; before that, or when the client says it is not
          known, Seal of Righteousness; Holy Strike (Forever: holy weapon strike,
          client data) and Judgement of Command (Forever: keeps the seal)
          on cooldown; Vengeance (Forever: up to 5 stacks of
          +3% physical and holy damage after crits, from level 29)
    HOLY  primary healing (HPS over the leveling cycle, Model.Sustained), secondary survival;
          Divine Intellect (+10% intellect), Illumination (5/5, Forever: a
          critical heal gives 50% of its mana back - crit saves mana)
    PROT  primary survival (effective health), secondary threat; Toughness
          (+10% armor from items)
  Each metric returns a number; Compare.lua turns differences into percent.
  Building blocks: Specs/Common.lua; heals: client spell data (Spells.lua).
  Guess(gear) picks a spec from the equipped gear while no talent points are spent:
  two-hander -> Ret; shield with healing gear -> Holy; shield -> Prot.
]]
local _, ns = ...
local Model, C, Character = ns.Model, ns.SpecCommon, ns.Character

-- Seal of Righteousness: holy damage per hit scales with weapon speed, so per
-- second it is coef * spell damage, independent of speed. 0.108 (2H) / 0.092
-- (1H) per second of weapon speed: most cited Classic figure (allakhazam
-- "spell coefficient (WoW)", reference talk page Seal of Righteousness).
-- Sources disagree (per-hit 10%/12% also quoted): marked uncertain.
local SOR_COEF = { twoHand = 0.108, oneHand = 0.092 }
-- Consecration: periodic, duration / 15 = 8 / 15 over 8 s (SpellCoeffsForever formula).
local CONSECRATION_PER_SEC = (8 / 15) / 8
local RIGHTEOUS_FURY = 1.6   -- Classic: +60% threat from holy spells
-- Seal of Command: client spell 20424 deals 70% weapon damage as Holy with a
-- spell power coefficient of 0.29 (client SpellEffect, build 70938); it
-- procs 7 times a minute (classic server data spell_proc_event 20375, ppmRate 7), so per
-- second it is 7/60 procs of the landed swings, whatever the weapon speed -
-- a slow weapon's bigger hit is what makes it better.
local SOC = { spell = 20375, level = 20, ppm = 7, weapon = 0.70, coef = 0.29 }
-- Judgement (client spell 20271): 10 s cooldown and, on Forever, it does not
-- consume the seal - so it is cast on cooldown. Judgement of Command (20467,
-- 20963-20966, one per Seal of Command rank, learned at 20/30/40/50/60):
-- `base` is the average holy damage on a stunned target; the tooltip says half
-- of it otherwise ($/2;20467s1). Spell power coefficient 0.429 (SpellEffect).
-- assumption: the coefficient applies in full (classic server data halves the base only);
-- it lands and crits like a spell of the paladin's melee crit (like the seal).
-- Seal of Righteousness' judgement (below level 20) is not counted.
local JOC = { cd = 10, coef = 0.429, ranks = {
    { level = 20, base = 97 }, { level = 30, base = 153 }, { level = 40, base = 214 },
    { level = 50, base = 274 }, { level = 60, base = 356 } } }
-- Vengeance (Forever, client spells 20049 / 20050, client build 70938):
-- 3 ranks of +1/2/3% (Forever trait data: TraitDefinitionEffectPoints, client build 70938; the spell's own
-- 5 is not the talent's value); a non-periodic crit gives +3% physical and holy
-- damage for 30 s, stacking 5 times (Classic: 5 ranks, one 8 s buff). Forever's
-- trait tree (TraitCond.SpentAmountRequired 20) -> level 29; the old Talent
-- table's row is stale. assumption: the standard Ret build takes it from then
-- on; a crit refreshes the stacks.
local VENGEANCE = { level = 29, perStack = 0.03, stacks = 5, duration = 30 }

-- Expected stacks: crits in the last 30 s are Poisson(mu), capped at 5 -
-- E[min(stacks, N)]. A steady state like Flurry's: leveling fights chain
-- within the buff's 30 s.
local function VengeanceStacks(mu)
    local p, below, sum = math.exp(-mu), 0, 0
    for k = 0, VENGEANCE.stacks - 1 do
        sum = sum + k * p
        below = below + p
        p = p * mu / (k + 1)
    end
    return sum + VENGEANCE.stacks * (1 - below)
end
ns.PaladinVengeance = VengeanceStacks  -- tests

local function SealDps(s, landed)
    local w = s.weapon
    local coef = (w and w.twoHand) and SOR_COEF.twoHand or SOR_COEF.oneHand
    return coef * Character.SpellPower(s, "holy") * landed
end

local function UsesCommand(s)
    local known = ns.Spells.Known(SOC.spell)
    if known ~= nil then return known end
    return s.level >= SOC.level
end

-- Holy damage: no armor; crits like a melee hit (assumption).
local function CommandDps(s, landed)
    local w = s.weapon or Model.UNARMED
    local hit = SOC.weapon * ((w.min + w.max) / 2 + s.ap / Model.AP_PER_DPS * w.speed)
        + SOC.coef * Character.SpellPower(s, "holy")
    local crit = math.min((s.crit or 0) / 100, 1)
    return SOC.ppm / 60 * landed * hit * (1 + (Model.CRIT_MULT - 1) * crit)
end

-- Judgement of Command per second, on cooldown (JOC above).
local function JudgementDps(s)
    local rank
    for _, r in ipairs(JOC.ranks) do if s.level >= r.level then rank = r end end
    if not rank then return 0 end
    local crit = math.min((s.crit or 0) / 100, 1)
    local hit = rank.base / 2 + JOC.coef * Character.SpellPower(s, "holy")
    return hit * (1 + (Model.CRIT_MULT - 1) * crit) * Model.SpellLanded(s) / JOC.cd
end

-- Vengeance's damage factor: crits per second from white swings, Seal of
-- Command procs, Judgement and Holy Strike (melee crit chance for all - assumption).
local function VengeanceFactor(s, landed, command)
    if s.level < VENGEANCE.level then return 1 end
    local w = s.weapon or Model.UNARMED
    local crit = math.max(0, math.min((s.crit or 0) / 100, landed))
    local strike = ns.Spells.Get("HOLY_STRIKE", s.level)
    local events = 1 / w.speed + (command and (SOC.ppm / 60 * landed + 1 / JOC.cd) or 0)
        + (strike and strike.cd > 0 and 1 / strike.cd or 0)
    return 1 + VENGEANCE.perStack * VengeanceStacks(events * crit * VENGEANCE.duration)
end

local function Damage(s)
    local white, landed = Model.WhiteDps(s)
    local command = UsesCommand(s)
    local seal = command and (CommandDps(s, landed) + JudgementDps(s)) or SealDps(s, landed)
    return (white + seal + C.OnCooldown(s, "HOLY_STRIKE")) * VengeanceFactor(s, landed, command)
        + (s.procDps or 0) * Model.SpellLanded(s)
end

-- Champion of the Light (Forever trait tree, 5/5, 25 points -> level 34):
-- spell damage +60% of intellect - feeds Seal and Judgement of Command.
-- assumption: the standard Ret build takes it.
local DAMAGE = C.Metric("damage", "DPS", C.FromIntellect(Damage, { { level = 34, spellDmg = 0.6 } }))
local HEALING = C.Metric("healing", "HPS", C.Healer({ big = { "HOLY_LIGHT" }, fast = { "FLASH_OF_LIGHT" }, critRefund = 0.5 }))
local SURVIVAL = C.SURVIVAL
local THREAT = C.Metric("threat", "TPS", function(s)
    local white, landed = Model.WhiteDps(s)
    local holy = SealDps(s, landed) + CONSECRATION_PER_SEC * Character.SpellPower(s, "holy")
    return white + RIGHTEOUS_FURY * holy
end)

ns.Specs = ns.Specs or {}
ns.Specs.PALADIN = {
    order = { "RET", "HOLY", "PROT" },
    trees = { "HOLY", "PROT", "RET" },
    specs = {
        RET  = { primary = DAMAGE, secondary = SURVIVAL },
        HOLY = { primary = HEALING, secondary = SURVIVAL, mana = true, statMult = { int = 1.1 } },
        PROT = { primary = SURVIVAL, secondary = THREAT, statMult = { armor = 1.1 } },
    },
    Guess = function(gear)
        local main, off = gear[16], gear[17]
        if main and main.equipLoc == "INVTYPE_2HWEAPON" then return "RET" end
        if off and off.equipLoc == "INVTYPE_SHIELD" then
            local heal, def = 0, 0
            for _, item in pairs(gear) do
                heal = heal + (item.stats.heal or 0)
                def = def + (item.stats.def or 0)
            end
            if heal >= 10 and heal > def * 2 then return "HOLY" end
            return "PROT"
        end
        return "RET"
    end,
}
