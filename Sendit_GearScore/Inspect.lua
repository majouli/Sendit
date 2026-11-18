--[[
  Inspect: known players (GearScore, item level, talents) by GUID.
  Sources: the player's own gear (live), and every INSPECT_READY - ours
  (hover, throttled) and Blizzard's (the inspect window) alike.
  Rules: never in combat, never while the inspect window is open (that
  would swap its target), one request per THROTTLE seconds, the last hovered
  player waits for the next free moment. Items of others may arrive uncached
  and talents a moment after INSPECT_READY: both are read again (READS).
  Our own inspect is cleared afterwards (ClearInspectPlayer), Blizzard's not.
  Contract: Inspect.Get(guid) -> entry | nil; Inspect.Request(unit);
  Inspect.Pending(guid); Inspect.OnChange(fn(guid, entry));
  entry = { name, class, level, score, ilvl, trees, t = time() }.
]]
local _, ns = ...
local Score, Talents = ns.Score, ns.Talents

local Inspect = {}
ns.Inspect = Inspect

local THROTTLE = 1.5
local TIMEOUT = 4
local REFRESH = 300               -- re-inspect a known player after this (gear changes)
local READS = { 0, 0.4, 1.2 }     -- talents / uncached items can lag INSPECT_READY
local CLEAR_AFTER = 1.5

local pending                     -- { guid, unit, at, ours }
local lastRequest = -math.huge
local queued                      -- unit token waiting for the throttle
local fresh = {}                  -- guid -> GetTime() of the last read this session
local listeners = {}

function Inspect.OnChange(fn) listeners[#listeners + 1] = fn end
local function Changed(guid, entry)
    for _, fn in ipairs(listeners) do fn(guid, entry) end
end

function Inspect.Get(guid)
    return guid and ns.data and ns.data.players[guid] or nil
end

function Inspect.Pending(guid)
    return pending ~= nil and pending.guid == guid and GetTime() - pending.at < TIMEOUT
end

function Inspect.Forget()
    wipe(fresh)
    Inspect.Own()
end

-- Blizzard's inspect window (load on demand, so looked up by name).
local function InspectWindow() return _G["InspectFrame"] end

local function InspectWindowOpen()
    local f = InspectWindow()
    return f ~= nil and f:IsShown()
end

local function Store(guid, entry)
    if not ns.data then return end
    entry.t = time()
    ns.data.players[guid] = entry
    fresh[guid] = GetTime()
    Changed(guid, entry)
end

local function Describe(unit)
    local name = ns.Call(UnitName, unit)
    return { name = name, class = ns.ClassOf(unit), level = ns.Call(UnitLevel, unit) }
end

-- Own entry: always current, no inspect needed.
function Inspect.Own()
    local guid = ns.GUID("player")
    if not guid then return end
    local entry = Describe("player")
    local r = Score.Unit("player")
    entry.score, entry.ilvl = r.score, r.ilvl
    entry.trees = Talents.Own()
    Store(guid, entry)
    if not r.complete then C_Timer.After(1, Inspect.Own) end
end

-- A unit token that still points at guid.
local function FindUnit(guid, hint)
    local candidates = { hint, "mouseover", "target", "focus", InspectWindow() and InspectWindow().unit }
    for i = 1, 4 do candidates[#candidates + 1] = "party" .. i end
    for i = 1, 40 do candidates[#candidates + 1] = "raid" .. i end
    for _, unit in pairs(candidates) do
        if unit and ns.GUID(unit) == guid then return unit end
    end
end

local function Read(guid, hint, step, best)
    local unit = FindUnit(guid, hint)
    if not unit then
        if best then Store(guid, best) end
        return
    end
    local entry = Describe(unit)
    local r = Score.Unit(unit)
    entry.score, entry.ilvl = r.score, r.ilvl
    entry.trees = Talents.Inspected(entry.class)
    -- keep the most complete talent read (a cleared inspect reads fewer points)
    if best and Talents.Total(best.trees) > Talents.Total(entry.trees) then entry.trees = best.trees end
    if r.count > 0 then Store(guid, entry) end
    local nextDelay = READS[step + 1]
    if nextDelay then
        C_Timer.After(nextDelay - READS[step], function() Read(guid, unit, step + 1, entry) end)
    end
end

ns.On("INSPECT_READY", function(guid)
    guid = ns.Safe(guid)
    if not guid then return end
    local ours = pending and pending.guid == guid
    local hint = ours and pending.unit or nil
    pending = nil
    Read(guid, hint, 1)
    if ours then
        C_Timer.After(READS[#READS] + CLEAR_AFTER, function()
            if not pending and not InspectWindowOpen() then pcall(ClearInspectPlayer) end
        end)
    end
end)

local function CanAsk(unit)
    if not (ns.db and ns.db.auto) or InCombatLockdown() or InspectWindowOpen() then return false end
    if not ns.Call(UnitIsPlayer, unit) then return false end
    local guid = ns.GUID(unit)
    if not guid or guid == ns.GUID("player") then return false end
    if fresh[guid] and GetTime() - fresh[guid] < REFRESH then return false end
    if Inspect.Pending(guid) then return false end
    if ns.Call(CanInspect, unit) ~= true then return false end
    -- the inspect range; a refused range check (combat rules) is no veto
    if ns.Call(CheckInteractDistance, unit, 1) == false then return false end
    return true, guid
end

function Inspect.Request(unit)
    local ok, guid = CanAsk(unit)
    if not ok then return false end
    local wait = lastRequest + THROTTLE - GetTime()
    if wait > 0 then
        local already = queued
        queued = unit
        if not already then
            C_Timer.After(wait, function()
                local u = queued
                queued = nil
                if u then Inspect.Request(u) end
            end)
        end
        return false
    end
    lastRequest = GetTime()
    pending = { guid = guid, unit = unit, at = GetTime() }
    pcall(NotifyInspect, unit)
    return true
end

-- talent and gear data are complete only after entering the world
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
                         "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE" }) do
    ns.On(event, function() Inspect.Own() end)
end
