--[[
  Service "quests": which quests reward an item, for other modules (the wardrobe's sources).
  Rewarding(itemID) -> { { id, name, level, faction = "alliance" | "horde" | nil, choice, done }, ... }
                       lowest level first; nil when no quest rewards it. done = already turned in.
  Open(id)   the browser at that quest
]]
local _, ns = ...
local DB = ns.Database
local index

local function Index()
    if index then return index end
    index = {}
    for id, q in pairs(ns.quests) do
        local r = q.rewards
        for _, kind in ipairs({ "items", "choice" }) do
            for _, e in ipairs(r and r[kind] or {}) do
                if e.itemId then
                    index[e.itemId] = index[e.itemId] or {}
                    table.insert(index[e.itemId], { id = id, choice = kind == "choice" })
                end
            end
        end
    end
    return index
end

local function Done(id)
    local api = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
    return ns.Read(api, id) == true
end

local function Rewarding(itemID)
    local list = Index()[itemID]
    if not list then return nil end
    local out = {}
    for _, e in ipairs(list) do
        local q = ns.quests[e.id]
        out[#out + 1] = { id = e.id, name = DB.Name(e.id), level = q.questLevel or q.requiredLevel or 0,
            faction = DB.Faction(e.id), choice = e.choice, done = Done(e.id) }
    end
    table.sort(out, function(a, b) return a.level < b.level end)
    return out
end

Sendit.Provide("quests", {
    Rewarding = Rewarding,
    Open = function(id) ns.Window:OpenQuest(id) end,
})
