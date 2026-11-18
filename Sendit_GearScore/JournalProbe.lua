--[[
  JournalProbe: /gs probe journal. Does Forever's dungeon journal deliver loot?
  That decides whether a gear planner can run on Blizzard's own data alone.
  Walks every tier, instance (dungeons and raids) and encounter through the
  journal API (EJ_* globals, C_EncounterJournal.GetLootInfoByIndex), loot
  filter cleared so every class's items count. Loot loads asynchronously
  (EJ_LOOT_DATA_RECIEVED), so it walks twice, the second time 3 s later, and
  keeps the larger counts. Result: Sendit_GearScoreDB.probeJournal (per instance:
  bosses, loot rows, a few sample items) and one chat line.
  Blizzard's journal UI is not loaded on Forever (its .toc excludes the
  vanilla game type), so selecting instances here disturbs no Blizzard window.
  Every call is pcall'd: a missing or refusing API is recorded, not an error.
]]
local _, ns = ...

local isSecret = issecretvalue or function() return false end
local SECOND_PASS = 3
local SAMPLES = 3

local function Plain(v)
    if isSecret(v) then return "<secret>" end
    return v
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

local API = { "EJ_GetNumTiers", "EJ_SelectTier", "EJ_GetInstanceByIndex", "EJ_SelectInstance",
              "EJ_GetEncounterInfoByIndex", "EJ_SelectEncounter", "EJ_GetNumLoot", "EJ_ResetLootFilter",
              "EJ_SetLootFilter", "EJ_GetDifficulty", "EJ_SetDifficulty", "EJ_GetLootInfoByIndex" }

local function LootRow(index)
    local cej = C_EncounterJournal
    local ok, info = Call(cej and cej.GetLootInfoByIndex, index)
    if ok and type(info) == "table" then
        return { itemID = Plain(info.itemID), name = Plain(info.name), link = Plain(info.link),
                 slot = Plain(info.slot), armorType = Plain(info.armorType), encounterID = Plain(info.encounterID) }
    end
    local ok2, a, b, c, d, e, f, g = Call(_G["EJ_GetLootInfoByIndex"], index)
    if ok2 and a ~= nil then
        return { legacy = { Plain(a), Plain(b), Plain(c), Plain(d), Plain(e), Plain(f), Plain(g) } }
    end
    return nil
end

-- One full walk; returns { instances = {...}, totals }.
local function Walk()
    local out = { instances = {}, encounters = 0, loot = 0, withItem = 0 }
    local cej = C_EncounterJournal
    if cej and cej.InitalizeSelectedTier then pcall(cej.InitalizeSelectedTier) end
    pcall(_G["EJ_ResetLootFilter"])
    pcall(_G["EJ_SetLootFilter"], 0, 0)
    local okTiers, tiers = Call(_G["EJ_GetNumTiers"])
    out.tiers = okTiers and Plain(tiers) or "<missing>"
    local tierCount = type(out.tiers) == "number" and out.tiers or 1
    for tier = 1, tierCount do
        pcall(_G["EJ_SelectTier"], tier)
        for _, raid in ipairs({ false, true }) do
            for index = 1, 200 do
                local ok, instanceID, name = Call(_G["EJ_GetInstanceByIndex"], index, raid)
                instanceID, name = ok and Plain(instanceID), ok and Plain(name)
                if type(instanceID) ~= "number" then break end
                pcall(_G["EJ_SelectInstance"], instanceID)
                local inst = { id = instanceID, name = name, raid = raid, tier = tier, bosses = 0, loot = 0, samples = {} }
                for e = 1, 40 do
                    local okE, encName, _, encounterID = Call(_G["EJ_GetEncounterInfoByIndex"], e, instanceID)
                    encounterID = okE and Plain(encounterID)
                    if type(encounterID) ~= "number" then break end
                    inst.bosses = inst.bosses + 1
                    pcall(_G["EJ_SelectEncounter"], encounterID)
                    local okN, n = Call(_G["EJ_GetNumLoot"])
                    n = okN and Plain(n) or 0
                    if type(n) ~= "number" then n = 0 end
                    inst.loot = inst.loot + n
                    for i = 1, n do
                        local row = LootRow(i)
                        if row and (row.itemID or row.legacy) then out.withItem = out.withItem + 1 end
                        if row and #inst.samples < SAMPLES then
                            row.boss = Plain(encName)
                            inst.samples[#inst.samples + 1] = row
                        end
                    end
                end
                out.encounters = out.encounters + inst.bosses
                out.loot = out.loot + inst.loot
                out.instances[#out.instances + 1] = inst
            end
        end
    end
    return out
end

-- Raw answers of the entry points, printed to chat: tiers, the current tier,
-- the first instances with and without initialising, Deadmines by map.
local function Raw(label, fn, ...)
    if type(fn) ~= "function" then
        ns.Print(label .. ": <missing>")
        return
    end
    local r = { pcall(fn, ...) }
    local parts = {}
    for i = 2, math.min(#r, 6) do parts[#parts + 1] = tostring(Plain(r[i])) end
    ns.Print(label .. ": " .. (r[1] and "" or "<error> ") .. table.concat(parts, ", "))
end

local function Diagnose()
    local cej = C_EncounterJournal or {}
    Raw("EJ_GetNumTiers", _G["EJ_GetNumTiers"])
    Raw("EJ_GetCurrentTier", _G["EJ_GetCurrentTier"])
    Raw("EJ_GetInstanceByIndex(1,false) before init", _G["EJ_GetInstanceByIndex"], 1, false)
    Raw("C_EncounterJournal.InitalizeSelectedTier", cej.InitalizeSelectedTier)
    Raw("EJ_SelectTier(1)", _G["EJ_SelectTier"], 1)
    Raw("EJ_GetInstanceByIndex(1,false)", _G["EJ_GetInstanceByIndex"], 1, false)
    Raw("EJ_GetInstanceByIndex(1,true)", _G["EJ_GetInstanceByIndex"], 1, true)
    Raw("GetInstanceForGameMap(36 Deadmines)", cej.GetInstanceForGameMap, 36)
    Raw("EJ_GetInstanceInfo(63)", _G["EJ_GetInstanceInfo"], 63)
    Raw("InstanceHasLoot(63)", cej.InstanceHasLoot, 63)
end

function ns.JournalProbe()
    Diagnose()
    local result = { time = date("%Y-%m-%d %H:%M"), build = { GetBuildInfo() }, api = {} }
    for _, name in ipairs(API) do result.api[name] = type(_G[name]) end
    local cej = C_EncounterJournal
    result.api["C_EncounterJournal.GetLootInfoByIndex"] = type(cej and cej.GetLootInfoByIndex)
    result.first = Walk()
    local events = 0
    local listener = CreateFrame("Frame")
    pcall(listener.RegisterEvent, listener, "EJ_LOOT_DATA_RECIEVED")
    listener:SetScript("OnEvent", function() events = events + 1 end)
    C_Timer.After(SECOND_PASS, function()
        listener:UnregisterAllEvents()
        result.second = Walk()
        result.lootEvents = events
        ns.data.probeJournal = result
        local s = result.second
        ns.Print(("Journal: %d instances, %d bosses, %d loot rows (%d with item), %d loot events. /reload to save.")
            :format(#s.instances, s.encounters, s.loot, s.withItem, events))
    end)
    ns.Print("Journal probe running (3 s)...")
end
