--[[
  Kills: the bosses killed in this run of an instance, per character (SavedVariablesPerCharacter
  SenditMapsKills = { [instance map ID] = { encs = { [encounterID] = true }, npcs = { [npcID] = true },
  left = time the player left } }). Any of these marks a boss:
  - the client's lock of the instance the player is in (GetInstanceLockTimeRemainingEncounter: killed
    bosses by name, also those killed before the addon ran), read on entering and after every kill;
  - a won encounter (ENCOUNTER_END, BOSS_KILL);
  - looting a boss (the loot's source is its corpse: GetLootSourceInfo) - works solo, where the lock keeps
    nothing and not every boss fight sends an encounter.
  Not used: the combat log and its death chat lines (forbidden to addons in this client).
  A run ends when the instance is reset (the client's reset message) or the player stayed out longer than
  EMPTY_RESET (the client resets an empty instance by then).
  Kills.Killed(id, enc, npc) -> true | nil;  Kills.OnChange(fn);  Kills.Report() -> lines (/maps probe kills)
]]
local _, ns = ...
local Kills = {}
ns.Kills = Kills

local EMPTY_RESET = 30 * 60  -- seconds
local SYNC_DELAY = 2         -- seconds after entering: the lock is known by then

local listeners = {}
local inside  -- the instance map ID the player is in

local function Plain(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end

local function Store()
    if type(SenditMapsKills) ~= "table" then SenditMapsKills = {} end
    return SenditMapsKills
end

local function Run(id)
    local store = Store()
    local run = store[id] or {}
    run.encs, run.npcs = run.encs or {}, run.npcs or {}
    store[id] = run
    return run
end

local function Changed() for _, fn in ipairs(listeners) do pcall(fn) end end

function Kills.OnChange(fn) listeners[#listeners + 1] = fn end

function Kills.Killed(id, enc, npc)
    local run = id and Store()[id]
    if not run then return nil end
    if enc and enc ~= 0 and run.encs and run.encs[enc] then return true end
    if npc and run.npcs and run.npcs[npc] then return true end
    return nil
end

local function Mark(npc, enc)
    if not inside then return end
    local run, changed = Run(inside), false
    if enc and enc ~= 0 and not run.encs[enc] then run.encs[enc], changed = true, true end
    if npc and not run.npcs[npc] then run.npcs[npc], changed = true, true end
    if changed then Changed() end
end

-- the client's own record of this instance's killed bosses (by name)
local function Sync()
    local lock, encounter = _G["GetInstanceLockTimeRemaining"], _G["GetInstanceLockTimeRemainingEncounter"]
    local svc = Sendit.Service("dungeons")
    if not (inside and lock and encounter and svc and svc.BossByName) then return end
    local ok, _, _, total = pcall(lock)
    if not ok or not Plain(total) or type(total) ~= "number" then return end
    for i = 1, total do
        local ok2, name, _, killed = pcall(encounter, i)
        if ok2 and Plain(name) and killed == true then
            local npc = svc.BossByName(inside, name)
            if npc then Mark(npc) end
        end
    end
end

-- a client text like "%s dies." as a pattern capturing the %s (nil without the text)
local function Pattern(global)
    local text = _G[global]
    if type(text) ~= "string" then return nil end
    return "^" .. text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
end

local GLOBALS = { reset = "INSTANCE_RESET_SUCCESS" }
local patterns = {}
local function Patterns()
    for key, global in pairs(GLOBALS) do patterns[key] = patterns[key] or Pattern(global) end
    return patterns
end

local function NpcOf(guid)
    if not (Plain(guid) and type(guid) == "string") then return nil end
    local kind, npc = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(npc)
end

-- the loot window's sources: a boss's corpse marks the boss
local function Looted()
    local count, source = _G["GetNumLootItems"], _G["GetLootSourceInfo"]
    local svc = Sendit.Service("dungeons")
    if not (inside and count and source and svc and svc.Boss) then return end
    local ok, n = pcall(count)
    for slot = 1, (ok and Plain(n) and n or 0) do
        local ok2, guid = pcall(source, slot)
        local npc = ok2 and NpcOf(guid)
        if npc and svc.Boss(npc) then Mark(npc) end
    end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ENCOUNTER_END", "BOSS_KILL", "CHAT_MSG_SYSTEM", "LOOT_OPENED" }) do
    events:RegisterEvent(e)
end
events:SetScript("OnEvent", function(_, event, a, _, _, _, success)
    local store = Store()
    if event == "PLAYER_ENTERING_WORLD" then
        local here = ns.Catalog.Here()
        if inside and inside ~= here and store[inside] then store[inside].left = time() end
        inside = here
        local run = here and store[here]
        if run and run.left and time() - run.left > EMPTY_RESET then store[here] = nil end
        if here and store[here] then store[here].left = nil end
        C_Timer.After(SYNC_DELAY, Sync)
        Changed()
    elseif event == "LOOT_OPENED" then
        Looted()
    elseif event == "ENCOUNTER_END" then
        if Plain(a) and Plain(success) and success == 1 then Mark(nil, a) end
        C_Timer.After(SYNC_DELAY, Sync)
    elseif event == "BOSS_KILL" then
        if Plain(a) then Mark(nil, a) end
        C_Timer.After(SYNC_DELAY, Sync)
    elseif event == "CHAT_MSG_SYSTEM" then
        local pattern = Patterns().reset
        if not (pattern and Plain(a) and type(a) == "string" and a:match(pattern)) then return end
        -- a reset only happens from outside: every run but the one the player is in ends
        for id in pairs(store) do if id ~= inside then store[id] = nil end end
        Changed()
    end
end)

-- what the client says about this instance's lock, and what is marked (for /maps probe kills)
function Kills.Report()
    local out = { "inside: " .. tostring(inside) }
    local lock, encounter = _G["GetInstanceLockTimeRemaining"], _G["GetInstanceLockTimeRemainingEncounter"]
    if lock then
        local ok, left, previous, total, done = pcall(lock)
        out[#out + 1] = ("lock: ok=%s left=%s previous=%s total=%s done=%s"):format(tostring(ok), tostring(left),
            tostring(previous), tostring(total), tostring(done))
        for i = 1, (ok and type(total) == "number" and total or 0) do
            local ok2, name, _, killed = pcall(encounter, i)
            out[#out + 1] = ("  %d %s killed=%s"):format(i, tostring(ok2 and name), tostring(ok2 and killed))
        end
    else
        out[#out + 1] = "lock: no API"
    end
    local run = inside and Store()[inside]
    local encs, npcs = {}, {}
    for k in pairs(run and run.encs or {}) do encs[#encs + 1] = k end
    for k in pairs(run and run.npcs or {}) do npcs[#npcs + 1] = k end
    out[#out + 1] = "marked encounters: " .. table.concat(encs, ", ") .. " | npcs: " .. table.concat(npcs, ", ")
    return out
end
