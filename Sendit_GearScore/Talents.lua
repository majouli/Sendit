--[[
  Talents: points per talent tree of the player or an inspected player.
  On Forever talents are C_Traits, not the Classic API (GetTalentTabInfo is
  missing, /gc probe): a class has ONE trait tree whose three node groups are
  the Classic trees. Points of a group = its currency "spent" (what Blizzard's
  talent window shows); if that reads 0 everywhere (inspected configs may not
  carry currency), the ranks of the group's nodes are summed instead.
  Inspected player = INSPECT_TRAIT_CONFIG_ID (-1) after INSPECT_READY; the
  client may fill it a moment later, so Inspect.lua reads again.
  Contract: Talents.Read(configID, class) -> { {name, points}, ... x3 } | nil;
  Talents.Own(); Talents.Inspected(class); Talents.Summary(trees) -> spec, "a/b/c".
  Everything is pcall'd and secret-checked: an unreadable tree is nil, never an error.
]]
local _, ns = ...
local L = ns.L
local Call, Safe = ns.Call, ns.Safe

local Talents = {}
ns.Talents = Talents

local function Number(v)
    v = Safe(v)
    return type(v) == "number" and v or 0
end

local function TreeID(configID)
    if not (C_Traits and C_Traits.GetConfigInfo) then return nil end
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

-- Currency per group, matched by ID (the answer order is not documented).
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

-- Fallback: node ranks per group. Purchased ranks when the config has any,
-- else the active rank (an inspected config may only carry that).
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

function Talents.Read(configID, class)
    if not configID then return nil end
    local treeID = TreeID(configID)
    if not treeID then return nil end
    local groups = Groups(treeID)
    if not groups then return nil end
    if SpentByCurrency(configID, groups) == 0 then SpentByNodes(configID, treeID, groups) end
    local names = class and L.trees[class] or {}
    local trees = {}
    for i, g in ipairs(groups) do
        local name = g.name
        if type(name) ~= "string" or name == "" then name = names[i] or ("#" .. i) end
        trees[i] = { name = name, points = g.points, icon = g.icon, groupID = g.id }
    end
    return trees
end

local function SpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then return Call(C_Spell.GetSpellTexture, spellID) end
    local legacy = _G["GetSpellTexture"]
    return legacy and Call(legacy, spellID) or nil
end

-- One node of the tree as drawn: Blizzard's layout position (pixels = pos / 10,
-- as TalentButtonUtil.TranslateNodePositionsToAnchorPositions), rank, spell.
local function Node(configID, nodeID, groupOf)
    local info = Call(C_Traits.GetNodeInfo, configID, nodeID)
    -- the nodes Blizzard's talent frame instantiates: visible, not SubTreeSelection
    if type(info) ~= "table" or Safe(info.isVisible) == false then return nil end
    local subTree = Enum and Enum.TraitNodeType and Enum.TraitNodeType.SubTreeSelection
    if subTree and Safe(info.type) == subTree then return nil end
    local x, y, maxRanks = Safe(info.posX), Safe(info.posY), Number(info.maxRanks)
    if type(x) ~= "number" or type(y) ~= "number" or maxRanks <= 0 then return nil end
    local group
    for _, gid in ipairs(type(info.groupIDs) == "table" and info.groupIDs or {}) do
        group = group or groupOf[Safe(gid)]
    end
    local entryID = type(info.activeEntry) == "table" and Safe(info.activeEntry.entryID)
    if not entryID and type(info.entryIDs) == "table" then entryID = Safe(info.entryIDs[1]) end
    local spellID, icon, name
    local entry = entryID and Call(C_Traits.GetEntryInfo, configID, entryID)
    local def = type(entry) == "table" and Safe(entry.definitionID) and Call(C_Traits.GetDefinitionInfo, entry.definitionID)
    if type(def) == "table" then
        spellID, icon, name = Safe(def.spellID), Safe(def.overrideIcon), Safe(def.overrideName)
    end
    if spellID and not icon then icon = SpellIcon(spellID) end
    local edges = {}
    for _, e in ipairs(type(info.visibleEdges) == "table" and info.visibleEdges or {}) do
        local target = type(e) == "table" and Safe(e.targetNode)
        if target then edges[#edges + 1] = { target = target, active = Safe(e.isActive) == true } end
    end
    return {
        id = nodeID, x = x / 10, y = y / 10, maxRanks = maxRanks, group = group,
        purchased = Number(info.ranksPurchased),
        active = math.max(Number(info.activeRank), Number(info.currentRank)),
        entryID = entryID, spellID = spellID, icon = icon, name = name, edges = edges,
    }
end

-- Everything the talent view draws: trees (headers) and nodes; nil = unreadable.
function Talents.Layout(configID, class)
    local trees = Talents.Read(configID, class)
    if not trees then return nil end
    local treeID = TreeID(configID)
    local ids = treeID and C_Traits.GetTreeNodes and Call(C_Traits.GetTreeNodes, treeID)
    if type(ids) ~= "table" then return nil end
    local groupOf = {}
    for _, t in ipairs(trees) do groupOf[t.groupID] = t end
    local nodes, purchased = {}, 0
    for _, nodeID in ipairs(ids) do
        local n = Safe(nodeID) and Node(configID, nodeID, groupOf)
        if n then
            nodes[#nodes + 1] = n
            purchased = purchased + n.purchased
        end
    end
    if #nodes == 0 then return nil end
    for _, n in ipairs(nodes) do
        n.rank = math.min(n.maxRanks, purchased > 0 and n.purchased or n.active)
    end
    return { trees = trees, nodes = nodes }
end

-- Own build: the active spec group's combat config, like the talent window;
-- the active config ID when that API is missing.
function Talents.Own()
    local configID
    local si = C_SpecializationInfo
    if si and si.GetActiveSpecGroup and si.GetCombatConfigIDForSpecGroup then
        local group = Call(si.GetActiveSpecGroup)
        configID = group and Call(si.GetCombatConfigIDForSpecGroup, group)
    end
    if not configID and C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        configID = Call(C_ClassTalents.GetActiveConfigID)
    end
    return Talents.Read(configID, ns.ClassOf("player"))
end

function Talents.InspectConfigID()
    local c = Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID
    return c or -1
end

function Talents.Inspected(class)
    return Talents.Read(Talents.InspectConfigID(), class)
end

function Talents.Total(trees)
    local n = 0
    for _, t in ipairs(trees or {}) do n = n + t.points end
    return n
end

-- "Vergeltung", "5/11/35"; nil spec when no point is spent.
function Talents.Summary(trees)
    if not trees then return nil end
    local best, points = nil, {}
    for i, t in ipairs(trees) do
        points[i] = t.points
        if t.points > 0 and (not best or t.points > best.points) then best = t end
    end
    return best and best.name or L.noTalents, table.concat(points, "/")
end
