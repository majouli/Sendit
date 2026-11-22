--[[
  Hunter - standard builds of the three trees (Classic reference).
  Auto shot (ranged weapon, ranged attack power 2 per agility, ranged crit)
  with the vendor arrows of the level (Mobs.Ammo), plus shots on cooldown
  (client data: weapon damage + flat bonus; Arcane Shot flat arcane damage,
  Serpent Sting kept up):
    BM  Multi-Shot; Unleashed Fury (Forever 5/5: pet +15% damage)
    MM  Aimed Shot and Multi-Shot; Mortal Shots (ranged crits 230%)
    SV  Multi-Shot; Lightning Reflexes (+15% agility)
  Careful Aim (Forever trait tree, 5/5, 5 points -> level 14): attack power
    +100% of intellect (melee and ranged) - Marksmanship only (the reference sim's
    sims: MM intellect = 1.00 attack power, BM / SV = 0).
  Aimed Shot's cast pausing auto shots is left out (assumption).
  The pet: its damage does not grow with the hunter's gear in Classic, but it
  is part of what kills the mob, so it is added as a constant - without it a
  better bow would read as twice the real gain. the classic server's pet stats
  (Pet.cpp): hunter pet weapon damage per second = level *
  (0.75 + 1.125) / 2 / 2 = 0.46875 * level; attack power 2 per strength - 20
  (creature rule) with strength from pet_levelstats (entry 1); happy pet +25%
  (assumption: kept happy), hit table of a normal melee attacker.
  Guess: Beast Mastery, the usual leveling tree.
]]
local _, ns = ...
local C, Model = ns.SpecCommon, ns.Model

-- classic server data pet_levelstats, creature_entry 1: strength by level
local PET_STR = { { 10, 31 }, { 20, 45 }, { 30, 61 }, { 40, 78 }, { 50, 113 }, { 60, 136 } }
local PET_DPS_PER_LEVEL = 0.46875
local HAPPY = 1.25
-- every tree: Multi-Shot and Arcane Shot on cooldown, Serpent Sting kept up
local SHOTS = { "MULTI_SHOT", "ARCANE_SHOT", "SERPENT_STING" }
local UNLEASHED_FURY = 1.15  -- 5/5 pet damage (Forever trait data: TraitDefinitionEffectPoints, client build 70938)

local function PetStrength(level)
    if level <= PET_STR[1][1] then return PET_STR[1][2] * level / PET_STR[1][1] end
    for i = 2, #PET_STR do
        local a, b = PET_STR[i - 1], PET_STR[i]
        if level <= b[1] then return a[2] + (b[2] - a[2]) * (level - a[1]) / (b[1] - a[1]) end
    end
    return PET_STR[#PET_STR][2]
end

local function PetDps(s)
    local ap = math.max(0, 2 * PetStrength(s.level) - 20)
    local t = Model.Target(s)
    local landed = 1 - (t.miss + t.dodge + t.parry) / 100
    return (PET_DPS_PER_LEVEL * s.level + ap / Model.AP_PER_DPS) * landed * HAPPY * Model.TargetArmorFactor(s)
end

local function WithPet(fn, mult)
    return function(s) return fn(s) + PetDps(s) * (mult or 1) end
end
local CAREFUL_AIM = { { level = 14, ap = 1.0, rap = 1.0 } }
ns.HunterPetDps = PetDps

ns.Specs = ns.Specs or {}
ns.Specs.HUNTER = {
    order = { "BM", "MM", "SV" },
    trees = { "BM", "MM", "SV" },
    specs = {
        BM = { primary = C.Metric("damage", "DPS", WithPet(C.Ranged({ shots = SHOTS }), UNLEASHED_FURY)),
               secondary = C.SURVIVAL },
        MM = { primary = C.Metric("damage", "DPS", C.FromIntellect(WithPet(C.Ranged({ shots = { "AIMED_SHOT", "MULTI_SHOT", "ARCANE_SHOT", "SERPENT_STING" }, critMult = 2.3 })), CAREFUL_AIM)),
               secondary = C.SURVIVAL },
        SV = { primary = C.Metric("damage", "DPS", WithPet(C.Ranged({ shots = SHOTS }))), secondary = C.SURVIVAL,
               statMult = { agi = 1.15 } },
    },
    Guess = function() return "BM" end,
}
