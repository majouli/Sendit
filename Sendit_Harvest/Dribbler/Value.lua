local _, ns = ...

local V = {}
ns.DribblerValue = V

V.AH_CUT = 0.05
V.BRACKETS = {
    { 5, 15 }, { 16, 20 }, { 21, 25 }, { 26, 30 }, { 31, 35 }, { 36, 40 },
    { 41, 45 }, { 46, 50 }, { 51, 55 }, { 56, 60 }, { 61, 99 },
}
local REQ_BELOW = 10
local QUALITIES = { 2, 3, 4 }
V.KINDS = { { 4, 2 }, { 4 }, { 2 } }

function V.Bracket(index)
    return V.BRACKETS[index]
end

function V.Label(index)
    local b = V.BRACKETS[index]
    if not b then return "" end
    return b[2] >= 99 and (b[1] .. "+") or (b[1] .. "-" .. b[2])
end

function V.IndexOf(itemLevel)
    for i, b in ipairs(V.BRACKETS) do
        if itemLevel >= b[1] and itemLevel <= b[2] then return i end
    end
    return nil
end

function V.Contains(index, itemLevel)
    local b = V.BRACKETS[index]
    return b ~= nil and itemLevel ~= nil and itemLevel >= b[1] and itemLevel <= b[2]
end

function V.QueryLevels(index)
    local b = V.BRACKETS[index]
    local lo = b[1] - REQ_BELOW
    return lo > 1 and lo or nil, b[2] < 99 and b[2] or nil
end

function V.MatPrice(id)
    local p = ns.Prices.Get(id)
    return p and p.p or nil
end

function V.OfYield(yield)
    if not yield then return nil, false end
    local sum, priced = 0, true
    for _, r in ipairs(yield) do
        local price = V.MatPrice(r.item)
        if price then
            sum = sum + r.chance * (r.min + r.max) / 2 * price
        else
            priced = false
        end
    end
    return math.floor(sum * (1 - V.AH_CUT) + 0.5), priced
end

function V.Expected(itemID, quality, itemLevel, classID, equipLoc)
    local yield = ns.Disenchant.Yield(ns.Disenchant.LootID(itemID, quality, itemLevel, classID, equipLoc))
    if not yield then return nil end
    local value, priced = V.OfYield(yield)
    return value, priced, yield
end

function V.ForItem(item)
    local yield = ns.Disenchant.ForItem(item)
    if not yield then return nil end
    return V.OfYield(yield)
end

function V.Classes(kind)
    return V.KINDS[kind] or V.KINDS[1]
end

function V.Mats(index, kind)
    local b = V.BRACKETS[index]
    if not b then return {} end
    local seen, out = {}, {}
    for _, class in ipairs(V.Classes(kind)) do
        for _, quality in ipairs(QUALITIES) do
            for _, row in ipairs(ns.DisenchantBrackets) do
                if row[1] == class and row[2] == quality and row[3] <= b[2] and row[4] >= b[1] then
                    for _, r in ipairs(ns.Disenchant.Yield(row[5]) or {}) do
                        local m = seen[r.item]
                        if not m then
                            m = { item = r.item, kind = r.kind, qualities = {}, price = V.MatPrice(r.item) }
                            seen[r.item] = m
                            out[#out + 1] = m
                        end
                        m.qualities[quality] = true
                    end
                end
            end
        end
    end
    local order = { dust = 1, essence = 2, shard = 3, crystal = 4 }
    table.sort(out, function(a, c)
        local x, y = order[a.kind] or 9, order[c.kind] or 9
        if x ~= y then return x < y end
        return a.item < c.item
    end)
    return out
end
