--[[
  Talents: points per tree (core Sendit.TalentPoints) with tree names, plus the node layout of the
  player or an inspected player. Inspected = config -1 after INSPECT_READY.
  Talents.Read(configID, class) -> { { name, points } x3 } | nil;  Own();  Inspected(class)
  Talents.Summary(trees) -> spec, "a/b/c". Everything pcall'd and secret-checked.
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

local Points = Sendit.TalentPoints

-- the trees with the client's names, else ours
function Talents.Read(configID, class)
    local trees = Points.Read(configID)
    if not trees then return nil end
    local names = class and L.trees[class] or {}
    for i, t in ipairs(trees) do
        if type(t.name) ~= "string" or t.name == "" then t.name = names[i] or ("#" .. i) end
    end
    return trees
end

local function SpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then return Call(C_Spell.GetSpellTexture, spellID) end
    local legacy = _G["GetSpellTexture"]
    return legacy and Call(legacy, spellID) or nil
end

-- one node as drawn: Blizzard's layout position (pixels = pos / 10), rank, spell
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

function Talents.Layout(configID, class)
    local trees = Talents.Read(configID, class)
    if not trees then return nil end
    local treeID = Points.TreeID(configID)
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

function Talents.Own()
    return Talents.Read(Points.OwnConfigID(), ns.ClassOf("player"))
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

function Talents.Summary(trees)
    if not trees then return nil end
    local best, points = nil, {}
    for i, t in ipairs(trees) do
        points[i] = t.points
        if t.points > 0 and (not best or t.points > best.points) then best = t end
    end
    return best and best.name or L.noTalents, table.concat(points, "/")
end
