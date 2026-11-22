--[[
  Tree: what the client knows about a talent config (C_Traits). Forever: one trait tree per class
  whose three node groups are the Classic trees. Reads are pcall'd and secret-checked.
  Tree.RankOf(configID) -> rankOf(nodeID)      current rank, staged points included
  Tree.Nodes(configID) -> { nodeID, ... }
  Tree.Names(configID) -> { [1..3] = tree name }
  Tree.Talent(configID, nodeID) -> name, max rank, icon, spellID
  Tree.Effect(configID, nodeID, rank) -> what the talent does at that rank (client text) | nil;
    nil for an English text on another client language (the server overrides some texts in English)
  Tree.Unspent(configID) -> unspent points | nil
  Tree.Open(configID) -> open(nodeID): false when Blizzard would refuse a point
]]
local _, ns = ...
local Call, Safe = ns.Call, ns.Safe

local Tree = {}
ns.Tree = Tree

local function NodeInfo(configID, nodeID)
    local info = C_Traits and Call(C_Traits.GetNodeInfo, configID, nodeID)
    return type(info) == "table" and info or nil
end

function Tree.RankOf(configID)
    local cache = {}
    return function(nodeID)
        local rank = cache[nodeID]
        if rank == nil then
            local info = NodeInfo(configID, nodeID)
            rank = info and (Safe(info.currentRank) or Safe(info.ranksPurchased)) or 0
            rank = type(rank) == "number" and rank or 0
            cache[nodeID] = rank
        end
        return rank
    end
end

local function TreeID(configID)
    local config = C_Traits and Call(C_Traits.GetConfigInfo, configID)
    return type(config) == "table" and type(config.treeIDs) == "table" and Safe(config.treeIDs[1]) or nil
end

function Tree.Nodes(configID)
    local treeID = TreeID(configID)
    local ids = treeID and Call(C_Traits.GetTreeNodes, treeID)
    local out = {}
    for _, id in ipairs(type(ids) == "table" and ids or {}) do
        id = Safe(id)
        if id then out[#out + 1] = id end
    end
    return out
end

function Tree.Names(configID)
    local treeID = TreeID(configID)
    local list = treeID and Call(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
    local groups = {}
    for _, g in ipairs(type(list) == "table" and list or {}) do
        local name = type(g) == "table" and Safe(g.displayName)
        if type(name) == "string" then
            groups[#groups + 1] = { name = name, order = Safe(g.orderIndex) or #groups }
        end
    end
    table.sort(groups, function(a, b) return a.order < b.order end)
    local names = {}
    for i, g in ipairs(groups) do names[i] = g.name end
    return names
end

function Tree.Open(configID)
    return function(nodeID)
        local info = NodeInfo(configID, nodeID)
        if not info then return true end
        if Safe(info.isAvailable) == false or Safe(info.meetsEdgeRequirements) == false then return false end
        local rank, max = Safe(info.currentRank), Safe(info.maxRanks)
        return not (type(rank) == "number" and type(max) == "number" and rank >= max)
    end
end

function Tree.Unspent(configID)
    local treeID = TreeID(configID)
    local list = treeID and Call(C_Traits.GetTreeCurrencyInfo, configID, treeID, false)
    local first = type(list) == "table" and list[1]
    local n = type(first) == "table" and Safe(first.quantity)
    return type(n) == "number" and n or nil
end

local function EntryID(info)
    return info and (type(info.activeEntry) == "table" and Safe(info.activeEntry.entryID)
        or type(info.entryIDs) == "table" and Safe(info.entryIDs[1]))
end

function Tree.Talent(configID, nodeID)
    local info = NodeInfo(configID, nodeID)
    local max = info and Safe(info.maxRanks)
    max = type(max) == "number" and max or nil
    local entryID = EntryID(info)
    local entry = entryID and Call(C_Traits.GetEntryInfo, configID, entryID)
    local defID = type(entry) == "table" and Safe(entry.definitionID)
    local def = defID and Call(C_Traits.GetDefinitionInfo, defID)
    if type(def) ~= "table" then return nil, max end
    local spellID = Safe(def.spellID)
    local name, icon = Safe(def.overrideName), Safe(def.overrideIcon)
    if (type(name) ~= "string" or name == "") and spellID and C_Spell then
        name = Call(C_Spell.GetSpellName, spellID)
    end
    if (not icon or icon == 0) and spellID and C_Spell then icon = Call(C_Spell.GetSpellTexture, spellID) end
    return name, max, icon, spellID
end

local function English(text)
    return text:find("%f[%a][Yy]ou%f[%A]") or text:find("%f[%a][Tt]he%f[%A]") or text:find("%f[%a][Yy]our%f[%A]")
end

function Tree.Effect(configID, nodeID, rank)
    local entryID, text = EntryID(NodeInfo(configID, nodeID)), nil
    if entryID and C_Traits.GetTraitDescription then
        text = Safe(Call(C_Traits.GetTraitDescription, entryID, rank))
    end
    if type(text) ~= "string" or text == "" then
        local _, _, _, spellID = Tree.Talent(configID, nodeID)
        if spellID and C_Spell and C_Spell.GetSpellDescription then
            text = Safe(Call(C_Spell.GetSpellDescription, spellID))
        end
    end
    if type(text) ~= "string" or text == "" then return nil end
    text = text:gsub("%s+", " ")
    if GetLocale() ~= "enUS" and English(text) then return nil end
    return text
end
