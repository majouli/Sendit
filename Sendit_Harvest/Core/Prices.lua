local _, ns = ...
local L = ns.L

local P = {}
ns.Prices = P

local CHEAP_SHARE = 0.15

function P.Robust(auctions)
    if not auctions or #auctions == 0 then return nil end
    local sorted, total = {}, 0
    for _, a in ipairs(auctions) do
        sorted[#sorted + 1] = a
        total = total + a.count
    end
    table.sort(sorted, function(a, b) return a.unit < b.unit end)

    local want = math.max(total * CHEAP_SHARE, sorted[1].count)
    local taken, sum = 0, 0
    for _, a in ipairs(sorted) do
        local n = math.min(a.count, want - taken)
        taken, sum = taken + n, sum + n * a.unit
        if taken >= want then break end
    end
    return math.floor(sum / taken + 0.5)
end

function P.Get(id)
    local prices = ns.db and ns.db.prices
    return prices and prices[id]
end

function P.Set(id, copper, t)
    ns.db.prices[id] = { p = copper, t = t }
end

function P.Count()
    local n = 0
    for _ in pairs(ns.db and ns.db.prices or {}) do n = n + 1 end
    return n
end

local GOLD = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:1:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:1:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:1:0|t"

function P.Money(copper)
    copper = math.floor(copper + 0.5)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then return s > 0 and (g .. GOLD .. " " .. s .. SILVER) or (g .. GOLD) end
    if s > 0 then return c > 0 and (s .. SILVER .. " " .. c .. COPPER) or (s .. SILVER) end
    return c .. COPPER
end

function P.Age(seconds)
    if seconds < 3600 then return L.ageMin:format(math.max(1, math.floor(seconds / 60))) end
    if seconds < 86400 then return L.ageHour:format(math.floor(seconds / 3600)) end
    local days = math.floor(seconds / 86400)
    return days == 1 and L.ageDay or L.ageDays:format(days)
end
