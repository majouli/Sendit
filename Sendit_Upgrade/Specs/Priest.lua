--[[
  Priest - standard builds of the three trees (Classic reference):
    DISC    Power Word: Shield on its Weakened Soul cooldown, Greater Heal
            family and Flash Heal; Mental Strength (+10% mana: modeled as +10%
            intellect, its mana share; uncertain)
    HOLY    Greater Heal family and Flash Heal; Spiritual Guidance (+25% of
            spirit as healing) - spirit counts; Divine Fury (-0.5 s on Heal
            and Greater Heal)
    SHADOW  Shadow Word: Pain kept up, Mind Blast on cooldown, Mind Flay
            (from level 20; else Smite) in between; Shadowform (Forever trait
            tree, 30 points -> level 39, client spell 15473: +100% critical
            strike damage bonus of Shadow spells - direct and periodic crit
            200%; assumption: the bonus counts from level 39 on, before at 150%)
  Guess: more +healing than +spell damage on the gear -> Holy, else Shadow.
]]
local _, ns = ...
local C = ns.SpecCommon

local BIG = { "LESSER_HEAL", "HEAL", "GREATER_HEAL" }

ns.Specs = ns.Specs or {}
ns.Specs.PRIEST = {
    order = { "DISC", "HOLY", "SHADOW" },
    trees = { "DISC", "HOLY", "SHADOW" },
    specs = {
        DISC = {
            primary = C.Metric("healing", "HPS", C.Healer({ big = BIG, fast = { "FLASH_HEAL" }, shield = "POWER_WORD_SHIELD" })),
            secondary = C.SURVIVAL, mana = true, statMult = { int = 1.1 },
        },
        HOLY = {
            primary = C.Metric("healing", "HPS", C.Healer({ big = BIG, fast = { "FLASH_HEAL" }, spiritToHeal = 0.25,
                                                         castDelta = { HEAL = -0.5, GREATER_HEAL = -0.5 } })),
            secondary = C.SURVIVAL, mana = true,
        },
        SHADOW = {
            primary = C.Metric("damage", "DPS", C.Caster({ dots = { "SHADOW_WORD_PAIN" }, cds = { "MIND_BLAST" },
                                                            filler = { "MIND_FLAY", "SMITE" },
                                                            critBonus = 1.0, dotCritBonus = 1.0 })),
            secondary = C.SURVIVAL, mana = true,
        },
    },
    Guess = function(gear)
        return C.Sum(gear, "heal") > C.Sum(gear, "spellDmg") and "HOLY" or "SHADOW"
    end,
}
