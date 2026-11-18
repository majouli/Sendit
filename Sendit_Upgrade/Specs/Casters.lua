--[[
  Mage and Warlock - standard builds of the three trees (warcraft.wiki.gg,
  Classic); spells and their ranks from the client data (Spells.lua).
    MAGE ARCANE       Arcane Missiles; Arcane Mind (Forever: one rank, +10%
                      intellect and +100% critical strike damage bonus of
                      Arcane spells - crits 200%; client spell 11232)
    MAGE FIRE         Fireball; Ignite (40% of a crit burns on: crit 150% ->
                      210%), Improved Fireball (-0.5 s cast)
    MAGE FROST        Frostbolt; Ice Shards (crits 200%), Improved Frostbolt
                      (-0.5 s cast)
    WARLOCK AFFLICTION  Corruption (instant: Improved Corruption) and Bane of
                      Agony kept up, Shadow Bolt in between (damage over time
                      crits on Forever, Model.Cast); Pandemic (Forever trait
                      tree, 3/3, 10 points -> level 19: Corruption / Bane of
                      Agony crits 200%; client spell 427712)
    WARLOCK DEMONOLOGY  Corruption kept up, Shadow Bolt; Demonic Embrace
                      (+15% stamina)
    WARLOCK DESTRUCTION Immolate kept up, Shadow Bolt; Bane (-0.5 s on both),
                      Ruin (crits 200%), Improved Shadow Bolt (Forever 5/5:
                      a Shadow Bolt crit -> +20% shadow damage taken for 12 s,
                      no charges - client spell 17794; assumption: only the
                      Destruction build takes it)
  Warlocks level with Life Tap (health into mana, eaten back) instead of
  drinking: mana does not limit them, intellect is worth its spell crit only.
  Guess: Mages Frost, Warlocks Affliction - the usual leveling trees.
]]
local _, ns = ...
local C = ns.SpecCommon

local function Dps(o) return C.Metric("damage", "DPS", C.Caster(o)) end

ns.Specs = ns.Specs or {}
ns.Specs.MAGE = {
    order = { "ARCANE", "FIRE", "FROST" },
    specs = {
        ARCANE = { primary = Dps({ filler = { "ARCANE_MISSILES" }, critBonus = 1.0 }), secondary = C.SURVIVAL, mana = true,
                   statMult = { int = 1.1 } },
        FIRE = { primary = Dps({ filler = { "FIREBALL" }, critBonus = 1.1, castDelta = { FIREBALL = -0.5 } }),
                 secondary = C.SURVIVAL, mana = true },
        FROST = { primary = Dps({ filler = { "FROSTBOLT" }, critBonus = 1.0, castDelta = { FROSTBOLT = -0.5 } }),
                  secondary = C.SURVIVAL, mana = true },
    },
    Guess = function() return "FROST" end,
}

ns.Specs.WARLOCK = {
    order = { "AFFLICTION", "DEMONOLOGY", "DESTRUCTION" },
    specs = {
        AFFLICTION = {
            primary = Dps({ dots = { "CORRUPTION", "CURSE_OF_AGONY" }, filler = { "SHADOW_BOLT" },
                            instant = { CORRUPTION = true }, lifeTap = true, dotCritBonus = 1.0 }),
            secondary = C.SURVIVAL, mana = true,
        },
        DEMONOLOGY = {
            primary = Dps({ dots = { "CORRUPTION" }, filler = { "SHADOW_BOLT" }, lifeTap = true }),
            secondary = C.SURVIVAL, mana = true, statMult = { sta = 1.15 },
        },
        DESTRUCTION = {
            primary = Dps({ dots = { "IMMOLATE" }, filler = { "SHADOW_BOLT" }, critBonus = 1.0,
                            critVuln = { key = "SHADOW_BOLT", pct = 0.20, dur = 12 },
                            castDelta = { SHADOW_BOLT = -0.5, IMMOLATE = -0.5 }, lifeTap = true }),
            secondary = C.SURVIVAL, mana = true,
        },
    },
    Guess = function() return "AFFLICTION" end,
}
