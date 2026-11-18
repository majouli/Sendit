--[[
  Weights: what each stat is worth for this character - a plausibility check
  of the model against known priorities (e.g. Retribution: hit > strength >
  crit / agility > attack power). Diagnostic output, English.

  /gc weights   per stat: the change of the spec's main metric in percent for
                a typical amount (10 points, 1 % for hit / crit), and the same
                in attack power equivalents (how much AP gives that much)

  Weights.Table(ctx) -> { { key, amount, pct, ap }, ... } (tests)
]]
local _, ns = ...
local Weights = {}
ns.Weights = Weights

local ROWS = {
    { "str", 10 }, { "agi", 10 }, { "ap", 10 }, { "crit", 1 }, { "hit", 1 },
    { "sta", 10 }, { "int", 10 }, { "spi", 10 }, { "spellDmg", 10 }, { "heal", 10 },
    { "spellCrit", 1 }, { "spellHit", 1 }, { "mp5", 5 }, { "armor", 100 },
}

local function Gain(ctx, delta)
    local fn = ctx.spec.primary.fn
    local base = fn(ctx.s)
    if base <= 0 then return 0 end
    local after = fn(ns.Character.Apply(ctx.s, ns.Compare._Scaled(ctx, delta)))
    return (after / base - 1) * 100
end

function Weights.Table(ctx)
    local perAP = Gain(ctx, { ap = 1 })
    local out = {}
    for _, row in ipairs(ROWS) do
        local pct = Gain(ctx, { [row[1]] = row[2] })
        out[#out + 1] = { key = row[1], amount = row[2], pct = pct, ap = perAP > 0 and pct / perAP or nil }
    end
    return out
end

function ns.commands.weights()
    local ctx, reason = ns.Compare.Context()
    if not ctx then ns.Print("no character data yet (" .. tostring(reason) .. ")") return end
    ns.Print(("weights for %s, level %d - %s (%s)"):format(ns.L.specs[ctx.specKey] or ctx.specKey, ctx.s.level,
        ctx.spec.primary.label, ctx.spec.primary.unit))
    for _, row in ipairs(Weights.Table(ctx)) do
        if math.abs(row.pct) > 1e-6 then
            local name = ns.StatNames[row.key] or row.key
            ns.Print(("  +%d %s: %+.2f %%%s"):format(row.amount, name, row.pct,
                row.ap and ("  = %.1f AP"):format(row.ap) or ""))
        end
    end
end
