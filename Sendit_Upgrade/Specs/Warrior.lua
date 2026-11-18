--[[
  Warrior - standard builds of the three trees (warcraft.wiki.gg, Classic):
    ARMS  two-hander; Mortal Strike on cooldown (from level 40); Impale
          (abilities crit for 220%) and Deep Wounds (a crit bleeds 60% of an
          average hit) make crit worth more
    FURY  dual wield; Dual Wield Specialization (off hand 50% -> 62.5%),
          Flurry (a crit hastes the next 3 swings by 30%), Bloodthirst on
          cooldown (45% of attack power, client data) from level 40; hit is
          worth more with the dual wield miss penalty; Furious Precision
          (Forever trait tree, 3/3, 10 points -> level 19: off hand +10% hit)
    all   Heroic Strike with the rage the cooldowns leave (rage from damage
          dealt, Common.Melee rageDump)
    PROT  primary survival with Toughness (+10% armor from items); secondary
          threat = melee damage (Defiance and stance multiply it - cancels)
  Guess: a shield -> Prot, two one-handers -> Fury, else Arms.
]]
local _, ns = ...
local C = ns.SpecCommon

ns.Specs = ns.Specs or {}
ns.Specs.WARRIOR = {
    order = { "ARMS", "FURY", "PROT" },
    specs = {
        ARMS = {
            primary = C.Metric("damage", "DPS", C.Melee({ cds = { "MORTAL_STRIKE" }, abilityCrit = 2.2, deepWounds = 0.6,
                                                         rageDump = "HEROIC_STRIKE" })),
            secondary = C.SURVIVAL,
        },
        FURY = {
            primary = C.Metric("damage", "DPS", C.Melee({ offhand = 0.625, offhandHit = 10, flurry = 0.3, cds = { "BLOODTHIRST" },
                                                           apAbility = true, rageDump = "HEROIC_STRIKE" })),
            secondary = C.SURVIVAL,
        },
        PROT = {
            primary = C.SURVIVAL, statMult = { armor = 1.1 },
            secondary = C.Metric("threat", "TPS", C.Melee({ rageDump = "HEROIC_STRIKE" })),
        },
    },
    Guess = function(gear)
        if C.HasShield(gear) then return "PROT" end
        if C.DualWields(gear) then return "FURY" end
        return "ARMS"
    end,
}
