--[[
  Service "dungeons": where an item drops, for other modules (the wardrobe's sources).
  Drops(itemID) -> { { id, boss = index, chance, dungeon = name, bossName, raid, min, max }, ... }
                   biggest chance first; nil when no boss drops it
  Open(id, bossIndex)   the browser at that dungeon, scrolled to the boss
]]
local _, ns = ...
local DB = ns.Database
local index

local function Index()
    if index then return index end
    index = {}
    for _, d in ipairs(DB.All()) do
        for b, boss in ipairs(d.bosses) do
            for i = 1, #boss.loot, 2 do
                local item = boss.loot[i]
                index[item] = index[item] or {}
                table.insert(index[item], { d = d, boss = b, chance = boss.loot[i + 1] })
            end
        end
    end
    return index
end

local function Drops(itemID)
    local list = Index()[itemID]
    if not list then return nil end
    local out = {}
    for _, e in ipairs(list) do
        out[#out + 1] = { id = e.d.id, boss = e.boss, chance = e.chance, dungeon = DB.Name(e.d),
            bossName = DB.BossName(e.d.bosses[e.boss]), raid = e.d.raid, min = e.d.min, max = e.d.max }
    end
    table.sort(out, function(a, b) return a.chance > b.chance end)
    return out
end

Sendit.Provide("dungeons", {
    Drops = Drops,
    Open = function(id, bossIndex) ns.Window:OpenAt(id, bossIndex) end,
})
