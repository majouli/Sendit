--[[
  Service "dungeons": where an item drops, for other modules (the wardrobe's sources).
  Drops(itemID) -> { { id, boss = index, chance, dungeon = name, bossName, raid, min, max }, ... }
                   biggest chance first; nil when no boss drops it
  Open(id, bossIndex)   the browser at that dungeon, scrolled to the boss
  Boss(npcID) -> { id, boss = index, enc (encounter ID, 0: none), name, display, rare, loot = { { itemID,
    chance % }, ... } } | nil  (the map's
    boss pins and their loot panel)
  Map(instanceMapID) -> { name (suite language), raid, min, max, art (loading screen file ID) } | nil
  BossByName(instanceMapID, name) -> npc | nil   a boss of that instance by its name in any language
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

local byNpc
local function Boss(npc)
    if not byNpc then
        byNpc = {}
        for _, d in ipairs(DB.All()) do
            for b, boss in ipairs(d.bosses) do
                if boss.npc and not byNpc[boss.npc] then byNpc[boss.npc] = { d = d, b = b } end
            end
        end
    end
    local e = byNpc[npc]
    if not e then return nil end
    local boss = e.d.bosses[e.b]  -- the name now: it follows a language switch
    return { id = e.d.id, boss = e.b, enc = boss.enc, name = DB.BossName(boss), display = boss.display, rare = boss.rare,
        loot = DB.Loot(boss) }
end

local function Fold(s) return type(s) == "string" and s:lower():gsub("[%s%p]", "") or nil end

local function BossByName(map, name)
    local want = Fold(name)
    if not want or want == "" then return nil end
    for _, d in ipairs(DB.All()) do
        if d.map == map then
            for _, boss in ipairs(d.bosses) do
                for _, names in pairs(ns.dungeonNames) do
                    local n = boss.name or (boss.enc ~= 0 and names.bosses[boss.enc]) or names.npcs[boss.npc]
                    if Fold(n) == want then return boss.npc end
                end
            end
        end
    end
    return nil
end

local function Map(map)
    local first
    for _, d in ipairs(DB.All()) do
        if d.map == map then
            if not d.wing then return { name = DB.Name(d), raid = d.raid, min = d.min, max = d.max, art = d.art } end
            first = first or d
        end
    end
    -- wings only (one instance, several group finder entries): the instance's level span
    if first then return { name = nil, raid = first.raid, min = first.min, max = first.max, art = first.art } end
    return nil
end

Sendit.Provide("dungeons", {
    Drops = Drops,
    Boss = Boss,
    Map = Map,
    BossByName = BossByName,
    Open = function(id, bossIndex) ns.Window:OpenAt(id, bossIndex) end,
})
