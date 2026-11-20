--[[
  Level: how close values sit to "Maximum", 0..1 - per entry, per group, overall. Entries without a
  best value (left alone by Maximum) do not count.
  ns.Level(e, mode) -> 0..1 | nil;  ns.GroupLevel(group, mode) / ns.TotalLevel(mode) -> 0..1 | nil
]]
local _, ns = ...

local function Clamp(x) return math.max(0, math.min(1, x)) end

function ns.Level(e, mode)
    local best = ns.Best(e)
    local v = ns.CVars.Get(e, mode)
    if best == nil or v == nil then return nil end
    if e.kind == "switch" then return v == best and 1 or 0 end
    if e.kind == "choice" then
        for i, c in ipairs(e.choices) do
            if c == v then return (i - 1) / (#e.choices - 1) end
        end
        return v > e.choices[#e.choices] and 1 or 0
    end
    local x = Clamp((v - e.lo) / (e.hi - e.lo))
    if best == e.lo then x = 1 - x end
    return x
end

local function Mean(entries, mode)
    local sum, n = 0, 0
    for _, e in ipairs(entries) do
        local x = ns.Level(e, mode)
        if x then sum, n = sum + x, n + 1 end
    end
    if n == 0 then return nil end
    return sum / n
end

function ns.GroupLevel(group, mode) return Mean(group.entries, mode) end

function ns.TotalLevel(mode)
    local all = {}
    for _, group in ipairs(ns.Catalog) do
        for _, e in ipairs(group.entries) do all[#all + 1] = e end
    end
    return Mean(all, mode)
end
