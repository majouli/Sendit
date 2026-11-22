--[[
  Shaman - standard builds of the three trees; talent values at full rank from
  the Forever trait data: TraitDefinitionEffectPoints, client build 70938:
    ELEMENTAL  Lightning Bolt; Elemental Fury (crits 200%), Lightning Mastery
               (Forever: -0.5 s cast)
    ENHANCE    melee damage; Forever lets the Shaman dual wield (Dual Wield 674,
               class mask Shaman) - an off-hand weapon counts when one is worn.
               Flurry (5/5: +30% attack speed for 3 swings after a crit),
               Windfury Weapon on the main hand,
               Stormstrike (100% weapon damage, 8 s) and Earth Shock on
               cooldown; Mental Dexterity (3/3, 5 points -> level 14: attack
               power +150% of intellect) and Mental Quickness (2/2, 20 points
               -> level 29: spell damage +30% of intellect) - Forever's trait
               tree, the Enhancement Shaman's intellect is worth attack power
    RESTO      Healing Wave plus Lesser Healing Wave; Improved Healing Wave
               (-0.5 s cast)
  Guess: +healing gear -> Resto, +spell damage -> Elemental, else Enhancement.
]]
local _, ns = ...
local C, Model = ns.SpecCommon, ns.Model

-- Windfury Weapon (Forever client spells 8233 / 8236 / 10484 / 16361, learned
-- at 30 / 40 / 50 / 60): each landed main-hand hit has a 20% chance of 2 extra
-- attacks with the rank's extra attack power (Classic: 1 attack). Elemental
-- Weapons (3/3, talent row 5, level 29+: standard build) raises the effect by 40%.
-- assumptions: the imbue sits on the main hand; extra attacks do not proc
-- Windfury again; Flurry's haste is left out of the proc rate.
local WINDFURY = { chance = 0.20, attacks = 2, talent = 1.40, ranks = {
    { level = 30, ap = 46 }, { level = 40, ap = 119 }, { level = 50, ap = 249 }, { level = 60, ap = 333 } } }

local function WindfuryDps(s)
    local rank
    for _, r in ipairs(WINDFURY.ranks) do if s.level >= r.level then rank = r end end
    if not rank then return 0 end
    local boosted = setmetatable({ ap = s.ap + rank.ap * WINDFURY.talent }, { __index = s })
    local perSwingDps, landed = Model.MainHandDps(boosted)  -- dual wield miss with an off hand
    return perSwingDps * landed * WINDFURY.chance * WINDFURY.attacks
end
ns.ShamanWindfury = WindfuryDps  -- tests

local enhanceMelee = C.Melee({ flurry = 0.3, cds = { "STORMSTRIKE", "EARTH_SHOCK" } })
-- Mental Dexterity (level 14) / Mental Quickness (level 29), see the header
local Enhance = C.FromIntellect(function(s) return enhanceMelee(s) + WindfuryDps(s) end,
    { { level = 14, ap = 1.5 }, { level = 29, spellDmg = 0.3 } })

ns.Specs = ns.Specs or {}
ns.Specs.SHAMAN = {
    order = { "ELEMENTAL", "ENHANCE", "RESTO" },
    trees = { "ELEMENTAL", "ENHANCE", "RESTO" },
    specs = {
        ELEMENTAL = { primary = C.Metric("damage", "DPS", C.Caster({ filler = { "LIGHTNING_BOLT" }, critBonus = 1.0,
                                                                         castDelta = { LIGHTNING_BOLT = -0.5 } })),
                      secondary = C.SURVIVAL, mana = true },
        ENHANCE = { primary = C.Metric("damage", "DPS", Enhance), secondary = C.SURVIVAL },
        RESTO = { primary = C.Metric("healing", "HPS", C.Healer({ big = { "HEALING_WAVE" }, fast = { "LESSER_HEALING_WAVE" },
                                                                    castDelta = { HEALING_WAVE = -0.5 } })),
                  secondary = C.SURVIVAL, mana = true },
    },
    Guess = function(gear)
        local heal, dmg = C.Sum(gear, "heal"), C.Sum(gear, "spellDmg")
        if heal > 0 and heal >= dmg then return "RESTO" end
        if dmg > 0 then return "ELEMENTAL" end
        return "ENHANCE"
    end,
}
