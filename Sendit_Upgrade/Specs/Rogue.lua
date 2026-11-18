--[[
  Rogue - standard builds of the three trees (warcraft.wiki.gg, Classic). All
  dual wield; the builder gets the energy the finishers leave (Common.Melee):
    ASSASSINATION  Sinister Strike (45 energy) with Lethality (Forever 2/2: crits 220%)
    COMBAT         Improved Sinister Strike (40 energy), Dual Wield
                   Specialization (off hand 50% -> 75%)
    SUBTLETY       Backstab with a dagger in the main hand (60 energy,
                   Opportunity +20%), else Hemorrhage (35 energy)
  Finishers (Eviscerate) and poisons do not scale with gear in Classic: left out.
  Guess: a dagger in the main hand -> Assassination, else Combat.
]]
local _, ns = ...
local C = ns.SpecCommon

local function SubtletyBuilder(s)
    if s.weapon and s.weapon.dagger then return { key = "BACKSTAB" } end
    return { key = "HEMORRHAGE" }
end

ns.Specs = ns.Specs or {}
ns.Specs.ROGUE = {
    order = { "ASSASSINATION", "COMBAT", "SUBTLETY" },
    specs = {
        ASSASSINATION = {
            primary = C.Metric("damage", "DPS", C.Melee({ builder = function() return { key = "SINISTER_STRIKE" } end,
                                                           abilityCrit = 2.2 })),
            secondary = C.SURVIVAL,
        },
        COMBAT = {
            primary = C.Metric("damage", "DPS", C.Melee({ offhand = 0.75,
                                                           builder = function() return { key = "SINISTER_STRIKE", cost = 40 } end })),
            secondary = C.SURVIVAL,
        },
        SUBTLETY = {
            primary = C.Metric("damage", "DPS", C.Melee({ builder = SubtletyBuilder, abilityBonus = 1.2 })),
            secondary = C.SURVIVAL,
        },
    },
    Guess = function(gear)
        return C.MainDagger(gear) and "ASSASSINATION" or "COMBAT"
    end,
}
