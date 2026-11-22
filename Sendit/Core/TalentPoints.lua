--[[
  TalentPoints: points per talent tree of the player or an inspected player. Forever: C_Traits, one
  trait tree per class whose three node groups are the Classic trees. Points = the group's spent
  currency, else the summed node ranks (inspected configs may lack currency). Everything pcall'd
  and secret-checked.
  Sendit.TalentPoints.Read(configID) -> { { name, points, icon, groupID } x3 in tree order } | nil
  TalentPoints.Own() -> the player's trees | nil;  TalentPoints.OwnConfigID();  TalentPoints.TreeID(configID)
  TalentPoints.Main(trees) -> index of the tree with the most points | nil (no points spent)
]]
local _, ns = ...
local TalentPoints = {}
ns.TalentPoints = TalentPoints

local isSecret = issecretvalue or function() return false end
local function Safe(v)
    if v == nil or isSecret(v) then return nil end
    return v
end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok then return nil end
    return Safe(v)
end
local function Number(v)
    v = Safe(v)
    return type(v) == "number" and v or 0
end

function TalentPoints.TreeID(configID)
    if not (configID and C_Traits and C_Traits.GetConfigInfo) then return nil end
    local config = Call(C_Traits.GetConfigInfo, configID)
    return type(config) == "table" and type(config.treeIDs) == "table" and Safe(config.treeIDs[1]) or nil
end

local function Groups(treeID)
    local list = C_Traits.GetGroupDisplayInfoByTreeID and Call(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
    if type(list) ~= "table" then return nil end
    local groups = {}
    for _, g in ipairs(list) do
        local id = type(g) == "table" and Safe(g.groupID)
        if id then
            groups[#groups + 1] = { id = id, name = Safe(g.displayName), icon = Safe(g.icon), order = Number(g.orderIndex), points = 0 }
        end
    end
    table.sort(groups, function(a, b) return a.order < b.order end)
    return #groups > 0 and groups or nil
end

-- currency per group, matched by ID (answer order not documented)
local function SpentByCurrency(configID, groups)
    if not C_Traits.GetGroupCurrencyInfo then return 0 end
    local ids, byID = {}, {}
    for _, g in ipairs(groups) do ids[#ids + 1] = g.id; byID[g.id] = g end
    local infos = Call(C_Traits.GetGroupCurrencyInfo, configID, ids)
    local total = 0
    for _, info in ipairs(type(infos) == "table" and infos or {}) do
        local g = byID[Safe(info.traitNodeGroupID)]
        local c = type(info.currencyInfos) == "table" and info.currencyInfos[1]
        if g and type(c) == "table" then
            g.points = Number(c.spent)
            total = total + g.points
        end
    end
    return total
end

-- fallback: node ranks per group - purchased ranks, else the active rank
local function SpentByNodes(configID, treeID, groups)
    local ids = C_Traits.GetTreeNodes and Call(C_Traits.GetTreeNodes, treeID)
    if type(ids) ~= "table" then return 0 end
    local byID = {}
    for _, g in ipairs(groups) do byID[g.id] = g end
    local purchased, active = {}, {}
    for _, nodeID in ipairs(ids) do
        local info = Safe(nodeID) and Call(C_Traits.GetNodeInfo, configID, nodeID)
        if type(info) == "table" and type(info.groupIDs) == "table" then
            for _, gid in ipairs(info.groupIDs) do
                local g = byID[Safe(gid)]
                if g then
                    purchased[g] = (purchased[g] or 0) + Number(info.ranksPurchased)
                    active[g] = (active[g] or 0) + math.max(Number(info.activeRank), Number(info.currentRank))
                end
            end
        end
    end
    local sumPurchased = 0
    for _, v in pairs(purchased) do sumPurchased = sumPurchased + v end
    local source = sumPurchased > 0 and purchased or active
    local total = 0
    for _, g in ipairs(groups) do
        g.points = source[g] or 0
        total = total + g.points
    end
    return total
end

function TalentPoints.Read(configID)
    local treeID = TalentPoints.TreeID(configID)
    if not treeID then return nil end
    local groups = Groups(treeID)
    if not groups then return nil end
    if SpentByCurrency(configID, groups) == 0 then SpentByNodes(configID, treeID, groups) end
    local trees = {}
    for i, g in ipairs(groups) do
        trees[i] = { name = g.name, points = g.points, icon = g.icon, groupID = g.id }
    end
    return trees
end

function TalentPoints.OwnConfigID()
    local si = C_SpecializationInfo
    if si and si.GetActiveSpecGroup and si.GetCombatConfigIDForSpecGroup then
        local group = Call(si.GetActiveSpecGroup)
        local configID = group and Call(si.GetCombatConfigIDForSpecGroup, group)
        if configID then return configID end
    end
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        return Call(C_ClassTalents.GetActiveConfigID)
    end
end

function TalentPoints.Own()
    return TalentPoints.Read(TalentPoints.OwnConfigID())
end

function TalentPoints.Main(trees)
    local best
    for i, t in ipairs(trees or {}) do
        if t.points > 0 and (not best or t.points > trees[best].points) then best = i end
    end
    return best
end
