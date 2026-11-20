--[[
  Probe: /gs probe - raw answers of the client APIs this addon relies on, stored in
  Sendit_GearScoreDB.probe; with a target also its inspect talent config (-1).
]]
local _, ns = ...
local L = ns.L

local isSecret = issecretvalue or function() return false end
local SECRET, MISSING = "<secret>", "<missing>"

local function Plain(v, depth)
    if isSecret(v) then return SECRET end
    if type(v) ~= "table" then
        if type(v) == "function" or type(v) == "userdata" then return "<" .. type(v) .. ">" end
        return v
    end
    if (depth or 0) >= 3 then return "<table>" end
    local out, n = {}, 0
    for k, x in pairs(v) do
        n = n + 1
        if n > 40 then out["..."] = true; break end
        if not isSecret(k) then out[k] = Plain(x, (depth or 0) + 1) end
    end
    return out
end

local function Try(fn, ...)
    if type(fn) ~= "function" then return MISSING end
    local r = { pcall(fn, ...) }
    if not r[1] then return "<error> " .. tostring(r[2]) end
    local out = {}
    for i = 2, #r do out[i - 1] = Plain(r[i]) end
    return #out <= 1 and (out[1] == nil and "<nil>" or out[1]) or out
end

local function Path(path)
    local v = _G
    for part in path:gmatch("[^%.]+") do
        if type(v) ~= "table" then return nil end
        v = v[part]
    end
    return v
end

local API = {
    "C_Traits.GetConfigInfo", "C_Traits.GetGroupDisplayInfoByTreeID", "C_Traits.GetGroupCurrencyInfo",
    "C_Traits.GetTreeNodes", "C_Traits.GetNodeInfo", "C_ClassTalents.GetActiveConfigID",
    "C_SpecializationInfo.GetActiveSpecGroup", "C_SpecializationInfo.GetCombatConfigIDForSpecGroup",
    "Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID", "NotifyInspect", "CanInspect", "ClearInspectPlayer",
    "CheckInteractDistance", "GetInventoryItemLink", "GetInventoryItemID", "C_Item.GetItemInfo",
    "C_Item.RequestLoadItemDataByID", "TooltipDataProcessor", "RAID_CLASS_COLORS",
    "PaperDollFrame", "CharacterModelScene", "CharacterModelFrame", "InspectModelScene", "InspectModelFrame",
}

local function Config(configID)
    local out = { configID = configID }
    local info = Try(C_Traits and C_Traits.GetConfigInfo, configID)
    out.configInfo = info
    local treeID = type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs[1] or nil
    if type(treeID) ~= "number" then return out end
    local groups = Try(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
    out.groups = groups
    local ids = {}
    for _, g in ipairs(type(groups) == "table" and groups or {}) do
        if type(g) == "table" and type(g.groupID) == "number" then ids[#ids + 1] = g.groupID end
    end
    out.currency = Try(C_Traits.GetGroupCurrencyInfo, configID, ids)
    local nodes = C_Traits.GetTreeNodes and select(2, pcall(C_Traits.GetTreeNodes, treeID))
    local sums, sample, count = {}, nil, 0
    for _, nodeID in ipairs(type(nodes) == "table" and nodes or {}) do
        local ok, n = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if ok and type(n) == "table" and not isSecret(n) then
            count = count + 1
            if not sample and (n.ranksPurchased or 0) > 0 then sample = Plain(n) end
            for _, gid in ipairs(type(n.groupIDs) == "table" and n.groupIDs or {}) do
                local s = sums[gid] or { purchased = 0, active = 0, current = 0 }
                s.purchased = s.purchased + (tonumber(Plain(n.ranksPurchased)) or 0)
                s.active = s.active + (tonumber(Plain(n.activeRank)) or 0)
                s.current = s.current + (tonumber(Plain(n.currentRank)) or 0)
                sums[gid] = s
            end
        end
    end
    out.nodeCount, out.nodeSums, out.nodeSample = count, sums, sample
    return out
end

local function Gear(unit)
    local slots = {}
    for _, slot in ipairs({ 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }) do
        local link = ns.Call(GetInventoryItemLink, unit, slot)
        if link then
            local score, ilvl, quality, equipLoc = ns.Score.Item(link, ns.Call(UnitLevel, unit))
            slots[slot] = { link = link, score = score, ilvl = ilvl, quality = quality, equipLoc = equipLoc }
        end
    end
    return { total = ns.Score.Unit(unit), slots = slots }
end

local probe
local function Save()
    ns.data.probe = probe
    local n = 0
    for _ in pairs(probe) do n = n + 1 end
    ns.Print(L.probeSaved:format(n))
end

function ns.commands.probe(rest)
    if rest == "journal" and ns.JournalProbe then return ns.JournalProbe() end
    probe = { build = Plain({ GetBuildInfo() }), locale = GetLocale(), time = date("%Y-%m-%d %H:%M"), api = {} }
    for _, name in ipairs(API) do
        local v = Path(name)
        probe.api[name] = v == nil and MISSING or (isSecret(v) and SECRET or type(v))
    end
    probe.ownGroup = Try(C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup)
    probe.ownActiveConfig = Try(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
    local group = type(probe.ownGroup) == "number" and probe.ownGroup
    probe.ownCombatConfig = group and Try(C_SpecializationInfo.GetCombatConfigIDForSpecGroup, group) or "<nil>"
    local ownID = type(probe.ownCombatConfig) == "number" and probe.ownCombatConfig or probe.ownActiveConfig
    if type(ownID) == "number" then probe.ownConfig = Config(ownID) end
    probe.ownTalents = ns.Talents.Own()
    probe.ownGear = Gear("player")

    local target = ns.Call(UnitIsPlayer, "target") and ns.GUID("target")
    if not target or target == ns.GUID("player") then
        ns.Print(L.probeNoTarget)
        Save()
        return
    end
    probe.inspect = { canInspect = Try(CanInspect, "target"), inRange = Try(CheckInteractDistance, "target", 1) }
    probe.inspect.notify = Try(NotifyInspect, "target")
    local waiting = true
    ns.On("INSPECT_READY", function(guid)
        if not waiting or ns.Safe(guid) ~= target then return end
        waiting = false
        C_Timer.After(1, function()
            local id = ns.Talents.InspectConfigID()
            probe.inspect.ready = true
            probe.inspect.config = Config(id)
            probe.inspect.talents = ns.Talents.Inspected(ns.ClassOf("target"))
            probe.inspect.gear = Gear("target")
            Save()
        end)
    end)
    C_Timer.After(6, function()
        if waiting then
            waiting = false
            probe.inspect.ready = false
            Save()
        end
    end)
end
