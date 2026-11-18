local _, ns = ...

local Loot = {}
ns.Loot = Loot

function Loot.Expand(flat, first)
    local out = {}
    for i = first or 1, #flat, 4 do
        local item = flat[i]
        out[#out + 1] = {
            item = item, chance = flat[i + 1] / 100, min = flat[i + 2], max = flat[i + 3],
            quality = ns.ItemQuality[item],
        }
    end
    return out
end

function Loot.Items()
    local list = {}
    for item in pairs(ns.ItemQuality) do list[#list + 1] = item end
    return list
end
