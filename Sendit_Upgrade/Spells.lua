--[[
  Spells: a spell or ability as the model needs it, at the player's level.

  Data: Data/Spells.lua, GENERATED from the Forever client's own spell tables
  (tools/gen_spells.py): every rank with its level, cost, cast time, cooldown,
  duration and parts - so a Forever change is one regeneration away, nothing is
  copied from Classic wikis. A part's value at the player's level:
  base + perLevel * (min(level, max level) - level learned).

  Rank: the highest one the character knows (IsSpellKnown); nil when the
  client says none is known; the highest the level allows when it cannot
  tell (marked `assumed`).

  Contract: Spells.Get(key, level) -> spell or nil
    spell = { key, id, rank, school, cost, power ("mana" | "rage" | "energy"),
              time (seconds of the cast, at least a global cooldown), cd, dur,
              direct = { min, max, avg, coef }   can crit
              dot    = { total, coef }           all ticks; damage ticks crit (Model.Cast)
              weapon = { flat, pct }             + pct % of a weapon hit
              absorb = { amount, coef }
              dummy, assumed }
  Spells.Best(keys, level) -> the known spell of a family with the biggest cast
]]
local _, ns = ...

local Spells = {}
ns.Spells = Spells

local GCD = 1.5  -- Classic global cooldown

-- Paladin heals keep the coefficients the Paladin model was built and checked
-- with: SpellCoeffsForever Data.lua overrides (MIT, "exact" for Forever). The
-- client's tables say 0.714 / 0.429 - sources disagree, marked uncertain.
Spells.COEF_OVERRIDE = { HOLY_LIGHT = 0.8571, FLASH_OF_LIGHT = 0.4286 }

-- true / false as the client says, nil when it cannot tell.
local function Known(id)
    local legacy = "IsPlayerSpell"
    local fn = (C_SpellBook and C_SpellBook.IsSpellKnown) or _G[legacy]
    if not fn then return nil end
    local ok, known = pcall(fn, id)
    if not ok then return nil end
    return known == true
end

Spells.Known = function(id) return Known(id) end

-- rank, assumed: the highest known rank; nil when the client says none is
-- known; the highest the level allows when it cannot tell.
local function Pick(ranks, level)
    local answered = false
    for i = #ranks, 1, -1 do
        local known = Known(ranks[i].id)
        if known ~= nil then answered = true end
        if known then return ranks[i], false end
    end
    if answered then return nil end
    local best
    for _, r in ipairs(ranks) do
        if r.level <= level then best = r end
    end
    return best, true
end

function Spells.Get(key, level)
    local spell = ns.SpellData and ns.SpellData[key]
    if not spell then return nil end
    local r, assumed = Pick(spell.ranks, level)
    if not r then return nil end
    local steps = math.max(math.min(level, r.max), r.level) - r.level
    local function At(base, perLevel) return base + perLevel * steps end
    local out = {
        key = key, id = r.id, rank = r.rank, school = spell.school, cost = r.cost, power = r.power,
        time = math.max(r.time, GCD), cd = r.cd, dur = r.dur, dummy = r.dummy, assumed = assumed,
    }
    if r.direct then
        local v = At(r.direct[1], r.direct[2])
        out.direct = { min = v * (1 - r.direct[3] / 2), max = v * (1 + r.direct[3] / 2), avg = v,
                       coef = Spells.COEF_OVERRIDE[key] or r.direct[4] }
    end
    if r.dot then
        out.dot = { total = At(r.dot[1], r.dot[2]) * r.dot[3], coef = r.dot[4] }
    end
    if r.weapon then
        out.weapon = { flat = At(r.weapon[1], r.weapon[2]), pct = r.weapon[3] }
    end
    if r.absorb then
        out.absorb = { amount = At(r.absorb[1], r.absorb[2]), coef = r.absorb[3] }
    end
    -- older callers: the direct part's numbers on the spell itself
    if out.direct then
        out.min, out.max, out.avg, out.coef = out.direct.min, out.direct.max, out.direct.avg, out.direct.coef
    end
    return out
end
Spells.Heal = Spells.Get

-- The best of a family the character can cast (Lesser Heal -> Heal ->
-- Greater Heal): the one with the most per cast.
function Spells.Best(keys, level)
    local best, bestAmount
    for _, key in ipairs(keys) do
        local sp = Spells.Get(key, level)
        local amount = sp and ((sp.direct and sp.direct.avg or 0) + (sp.dot and sp.dot.total or 0))
        if sp and (not best or amount > bestAmount) then best, bestAmount = sp, amount end
    end
    return best
end
