--[[
  Recorder: writes down what bosses drop when you loot them - the creature's NPC ID, the instance map,
  its name when you target it, the encounter just won, how often it was looted and how often each
  wearable item (green or better) dropped. Tracked: creatures our data knows as a boss, and anything
  looted within ENCOUNTER_WINDOW seconds of a won encounter (Forever's own bosses). Only plain values.
  Used at once (new items join the boss's loot) and merged into the data by tools/gen_dungeons.py.
  A corpse without loot opens no window: kills count lootable corpses only (assumption: bosses always
  carry loot). A drop chance only from MIN_KILLS kills on, before that "unknown" (0).
  SenditDungeonsSeen (account) = { version, npcs = { [npcID] = { map, name, kills, items = { [itemID] =
                                   drops }, encs = { [encounterID] = kills }, seen } } }
  Recorder.Loot()  read the open loot window;  Recorder.Encounter(id, success);  Recorder.Apply(only)
  Recorder.Chance(rec, itemID) -> percent | 0
]]
local _, ns = ...
local Recorder = {}
ns.Recorder = Recorder

local ENCOUNTER_WINDOW = 180
local MIN_KILLS = 5
local MIN_QUALITY = 2
local LOOT_ITEM = 1 -- Enum.LootSlotType.Item
local looted = {}   -- corpse GUIDs counted this session
local lastEncounter, lastEncounterAt

local function Plain(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e, f, g, h
end

local function Store()
    SenditDungeonsSeen = type(SenditDungeonsSeen) == "table" and SenditDungeonsSeen or {}
    SenditDungeonsSeen.version = SenditDungeonsSeen.version or 1
    SenditDungeonsSeen.npcs = SenditDungeonsSeen.npcs or {}
    return SenditDungeonsSeen.npcs
end

local bossByNpc
local function Bosses()
    if not bossByNpc then
        bossByNpc = {}
        for _, d in ipairs(ns.Database.All()) do
            for _, b in ipairs(d.bosses) do
                if b.npc and b.npc > 0 then bossByNpc[b.npc] = b end
            end
        end
    end
    return bossByNpc
end

-- "Creature-0-<server>-<instance>-<zone>-<npcID>-<spawn>"
local function NpcID(guid)
    if not (Plain(guid) and type(guid) == "string") then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind == "Creature" then return tonumber(id) end
    return nil
end

local function NameOf(guid)
    for _, unit in ipairs({ "target", "mouseover" }) do
        local g = Call(UnitGUID, unit)
        if Plain(g) and g == guid then
            local name = Call(UnitName, unit)
            if Plain(name) and type(name) == "string" and name ~= "" then return name end
        end
    end
    return nil
end

local function Wearable(itemID, quality)
    if not (Plain(quality) and type(quality) == "number" and quality >= MIN_QUALITY) then return false end
    local _, _, _, equipLoc = Call(C_Item and C_Item.GetItemInfoInstant, itemID)
    return Plain(equipLoc) and type(equipLoc) == "string" and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
end

local function ItemID(slot)
    local link = Call(GetLootSlotLink, slot)
    if not (Plain(link) and type(link) == "string") then return nil end
    return tonumber(link:match("|Hitem:(%d+)"))
end

local function InInstance()
    local _, kind, _, _, _, _, _, map = Call(GetInstanceInfo)
    if not (Plain(kind) and (kind == "party" or kind == "raid") and Plain(map) and type(map) == "number") then return nil end
    return map
end

local function RecentEncounter()
    local now = Call(GetTime)
    if lastEncounter and Plain(now) and now - lastEncounterAt <= ENCOUNTER_WINDOW then return lastEncounter end
    return nil
end

function Recorder.Encounter(id, success)
    if Plain(id) and type(id) == "number" and success == 1 then
        lastEncounter, lastEncounterAt = id, Call(GetTime) or 0
    end
end

-- per corpse GUID: { npc, items = { itemID, ... } }
local function Corpses()
    local count = Call(GetNumLootItems)
    if not (Plain(count) and type(count) == "number") then return {} end
    local out = {}
    for slot = 1, count do
        local sources = { Call(GetLootSourceInfo, slot) }
        local itemID = Call(GetLootSlotType, slot) == LOOT_ITEM and ItemID(slot)
        local _, _, _, _, quality = Call(GetLootSlotInfo, slot)
        local keep = itemID and Wearable(itemID, quality)
        for i = 1, #sources, 2 do
            local guid = sources[i]
            local npc = NpcID(guid)
            if npc and guid then
                local corpse = out[guid] or { npc = npc, items = {} }
                out[guid] = corpse
                if keep then table.insert(corpse.items, itemID) end
            end
        end
    end
    return out
end

function Recorder.Loot()
    local map = InInstance()
    if not map then return 0 end
    local enc, known, npcs, n = RecentEncounter(), Bosses(), Store(), 0
    for guid, corpse in pairs(Corpses()) do
        if not looted[guid] and (known[corpse.npc] or enc) then
            looted[guid] = true
            local rec = npcs[corpse.npc] or { kills = 0, items = {}, encs = {} }
            rec.map, rec.kills = map, rec.kills + 1
            rec.name = NameOf(guid) or rec.name
            if enc then rec.encs[enc] = (rec.encs[enc] or 0) + 1 end
            for _, itemID in ipairs(corpse.items) do rec.items[itemID] = (rec.items[itemID] or 0) + 1 end
            rec.seen = Call(time)
            npcs[corpse.npc] = rec
            Recorder.Apply(corpse.npc)
            n = n + 1
        end
    end
    return n
end

function Recorder.Chance(rec, itemID)
    if rec.kills < MIN_KILLS then return 0 end
    return math.floor((rec.items[itemID] or 0) / rec.kills * 1000 + 0.5) / 10
end

-- items the bundled data lacks join the boss's loot
function Recorder.Apply(only)
    local known = Bosses()
    for npc, rec in pairs(Store()) do
        local boss = (not only or npc == only) and known[npc]
        if boss and type(rec.items) == "table" then
            local at = {}
            for i = 1, #boss.loot, 2 do at[boss.loot[i]] = i end
            boss.recorded = boss.recorded or {}
            for itemID in pairs(rec.items) do
                local i = at[itemID]
                if not i then
                    i = #boss.loot + 1
                    boss.loot[i] = itemID
                    boss.recorded[itemID] = true
                    boss.known = true
                end
                if boss.recorded[itemID] then boss.loot[i + 1] = Recorder.Chance(rec, itemID) end
            end
        end
    end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "LOOT_READY", "ENCOUNTER_END" }) do events:RegisterEvent(e) end
events:SetScript("OnEvent", function(_, event, a, _, _, _, success)
    if event == "ADDON_LOADED" then
        if a == "Sendit_Dungeons" then Store() Recorder.Apply() end
    elseif event == "ENCOUNTER_END" then
        Recorder.Encounter(a, success)
    else
        Recorder.Loot()
    end
end)
