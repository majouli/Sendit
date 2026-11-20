--[[
  Druid - standard builds of the trees; talent values at full rank from the
  Forever trait data (TraitDefinitionEffectPoints, client build 70938).
  Feral Combat counts twice, as its two roles:
    BALANCE  spell damage: Wrath or Starfire (the better one known); Vengeance
             (5/5: crits 200%), Improved Wrath / Improved Starfire (-0.5 s cast),
             Nature's Grace (Forever: a non-periodic crit -> +10% casting speed
             and global cooldown for 3 s; client spells 16880 / 16886)
    CAT      melee damage in Cat Form plus Claw from the energy finishers leave
             (Common.Melee builder); Ferocity (Claw 45 -> 40 energy), Heart of
             the Wild (Forever 5/5: +10% strength in Cat); Claw hits at the
             paw's own speed (assumption: no weapon normalization for a form's paw)
    BEAR     survival in Bear Form; Heart of the Wild (+20% stamina in Bear);
             Thick Hide gives flat base armor on Forever (live, not per item);
             threat = bear melee damage
    Predatory Strikes (3/3): +150% of the level as attack power in Cat / Bear /
             Dire Bear Form; form attack power (client spells 3025 / 1178 /
             9635): Cat +12, Bear +30, Dire Bear +120.
    RESTO    healing: Healing Touch plus Rejuvenation; Improved Healing Touch
             (-0.5 s cast)

  Forms ignore the weapon's damage: the paw swing comes from the druid's level
  and attack power. Attack power in a form = the caster form's (live, already
  2 per strength) + 1 per agility in Cat Form (reference "Cat Form",
  Classic) + the weapon's "attack power in Cat, Bear and Dire Bear form"
  (feralAp) + the form's flat attack power (above). Armor in Bear Form: see
  BEAR_ARMOR below (item armor only, Forever client data).
  Already in a form when the snapshot was taken: its live attack power /
  armor hold the form's part: attack power starts from the caster form's
  (form part taken out), Bear armor gives its bonus only to the change.
  Uncertain (marked): the paw's base damage per level - an assumption; it is
  the same for both items compared, so it shifts the size of a percent, not
  which item is better.
  Guess: in Cat / Bear Form that form (leveling gear often carries some
  +healing - the form is the stronger sign); else +healing gear -> Resto, +spell damage -> Balance, defense -> Bear,
  else Cat.
]]
local _, ns = ...
local C, Model = ns.SpecCommon, ns.Model
local Druid = {}
ns.Druid = Druid

local CAT_AP_PER_AGI = 1       -- reference "Cat Form" (Classic)
local PAW_DPS_PER_LEVEL = 1.0  -- assumption: base paw damage per second per level
local CAT_SPEED, BEAR_SPEED = 1.0, 2.5  -- Classic form attack speeds
-- Bear Form (5487 -> 1178, level 10) / Dire Bear Form (9634 -> 9635, level 40),
-- Forever client data (client build 70938): armor from ITEMS +180% / +360%
-- (agility's armor not), health +20 / +600 (flat).
local BEAR_ARMOR, DIRE_BEAR_ARMOR, DIRE_BEAR_LEVEL = 1.8, 3.6, 40
local BEAR_HP, DIRE_BEAR_HP = 20, 600
local ARMOR_PER_AGI = 2  -- as Character.lua (reference "Agility", Classic)

-- The snapshot as a form sees it: paw instead of the weapon, form attack power.
-- In a form at the snapshot, the live attack power holds that form's part
-- (feral attack power, in Cat Form 1 per agility): taken out first, so every
-- form starts from the caster form's attack power.
local PREDATORY_STRIKES = 1.5  -- attack power per level in a form (3/3)

-- The flat attack power a form adds: its own plus Predatory Strikes.
local function FormAp(s, form)
    local own = form == "cat" and 12 or (s.level >= DIRE_BEAR_LEVEL and 120 or 30)
    return own + PREDATORY_STRIKES * s.level
end

local function CasterAp(s)
    if not s.form then return s.ap end
    local feral = s.liveFeralAp or 0
    local agi = s.form == "cat" and CAT_AP_PER_AGI * (s.liveAgi or 0) or 0
    return s.ap - feral - agi - FormAp(s, s.form)
end

local function Form(s, speed, apPerAgi, form)
    local dps = PAW_DPS_PER_LEVEL * s.level
    local f = setmetatable({}, { __index = s })
    f.weapon = { min = dps * speed, max = dps * speed, speed = speed, paw = true }
    f.offWeapon = nil
    f.ap = CasterAp(s) + (apPerAgi or 0) * s.agi + (s.feralAp or 0) + FormAp(s, form)
    return f
end
Druid._Form = Form

-- Natural Instinct (Forever trait tree, 2/2, 20 points -> level 29): +20% critical
-- strike damage bonus of melee abilities - Claw crits 220%. assumption: the
-- standard Cat build takes it.
local CAT_MELEE = C.Melee({ builder = function() return { key = "CLAW", cost = 40 } end, abilityCrit = 2.2 })

local function Cat(s)
    return CAT_MELEE(Form(s, CAT_SPEED, CAT_AP_PER_AGI, "cat"))
end

local function Bear(s)
    return (Model.WhiteDps(Form(s, BEAR_SPEED, 0, "bear")))
end

local function BearSurvival(s)
    local f = setmetatable({}, { __index = s })
    local dire = s.level >= DIRE_BEAR_LEVEL
    local mult = 1 + (dire and DIRE_BEAR_ARMOR or BEAR_ARMOR)
    local agiArmor = ARMOR_PER_AGI * (s.agi or 0)
    if s.form == "bear" then
        -- live armor and health already hold the form: only the item armor change gets the bonus
        local agiChange = agiArmor - ARMOR_PER_AGI * (s.liveAgi or s.agi or 0)
        f.armor = s.liveArmor + (s.armor - s.liveArmor - agiChange) * mult + agiChange
    else
        f.armor = math.max(0, s.armor - agiArmor) * mult + agiArmor
        f.hp = s.hp + (dire and DIRE_BEAR_HP or BEAR_HP)
    end
    return Model.Survival(f)
end

ns.Specs = ns.Specs or {}
ns.Specs.DRUID = {
    order = { "BALANCE", "CAT", "BEAR", "RESTO" },
    specs = {
        BALANCE = { primary = C.Metric("damage", "DPS", C.Caster({ filler = { "WRATH", "STARFIRE" }, critBonus = 1.0,
                                                                       critHaste = { pct = 0.10, dur = 3 },
                                                                       castDelta = { WRATH = -0.5, STARFIRE = -0.5 } })),
                    secondary = C.SURVIVAL, mana = true },
        CAT = { primary = C.Metric("damage", "DPS", Cat), secondary = C.SURVIVAL, statMult = { str = 1.1 } },
        BEAR = { primary = C.Metric("survival", "EHP", BearSurvival),
                 secondary = C.Metric("threat", "TPS", Bear), statMult = { sta = 1.2 } },
        RESTO = { primary = C.Metric("healing", "HPS", C.Healer({ big = { "HEALING_TOUCH" }, fast = { "REJUVENATION" },
                                                                     castDelta = { HEALING_TOUCH = -0.5 } })),
                  secondary = C.SURVIVAL, mana = true },
    },
    Guess = function(gear, s)
        if s and s.form then return s.form == "cat" and "CAT" or "BEAR" end
        local heal, dmg, def = C.Sum(gear, "heal"), C.Sum(gear, "spellDmg"), C.Sum(gear, "def")
        if heal > 0 and heal >= dmg then return "RESTO" end
        if dmg > 0 then return "BALANCE" end
        if def > 0 then return "BEAR" end
        return "CAT"
    end,
}
