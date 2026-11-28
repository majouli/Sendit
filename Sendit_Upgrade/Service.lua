--[[
  Service: Upgrade's rating for the other modules (Sendit.Provide "upgrade"), the tooltip's calculation.
  Rate(itemID | link) -> r = { status, pct, slotPct, empty, equipLoc, label, unit, secondaryPct,
                        secondaryLabel, gate }   status "ok" | "loading" | "unusable" | ...
  Spec() -> the rated specialization's name;  Specs() -> { { key, name } } of the class
  RateFor(item, specKey) -> r like Rate, for another spec (a second spec)
  WeaponScore(item, specKey) -> gain with both hands empty (weapons, shields, off-hands of a second spec) |
    nil, status
  OnChange(fn)   gear, level, spec or enemy level changed: ratings are stale (gear and level once the
                 character settled: SETTLE s without a gear, level or stats event)
]]
local _, ns = ...

local listeners = {}
local function Changed()
    for _, fn in ipairs(listeners) do pcall(fn) end
end

local api = {}

function api.Rate(item)
    local r = ns.Compare.Evaluate(type(item) == "string" and item or "item:" .. tostring(item))
    if not r then return { status = "noCompare" } end
    if r.status ~= "ok" then return { status = r.status } end
    return { status = "ok", pct = r.primary.pct, slotPct = r.primary.slotPct, empty = r.primary.slotEmpty,
        label = r.primary.label, secondaryPct = r.secondary and r.secondary.pct,
        secondaryLabel = r.secondary and r.secondary.label,
        unit = r.primary.unit, gate = r.levelGate, equipLoc = r.item and r.item.equipLoc }
end

function api.RateFor(item, specKey)
    local r = ns.Compare.Evaluate(type(item) == "string" and item or "item:" .. tostring(item), specKey)
    if not r then return { status = "noCompare" } end
    if r.status ~= "ok" then return { status = r.status } end
    return { status = "ok", pct = r.primary.pct, label = r.primary.label, gate = r.levelGate }
end

function api.WeaponScore(item, specKey)
    return ns.Compare.WeaponScore(type(item) == "string" and item or "item:" .. tostring(item), specKey)
end

function api.Specs()
    local ok, ctx = pcall(ns.Compare.Context)
    local list = {}
    for _, key in ipairs(ok and ctx and ctx.classData.order or {}) do
        list[#list + 1] = { key = key, name = ns.L.specs[key] or key }
    end
    return list
end

function api.Spec()
    local ok, ctx = pcall(ns.Compare.Context)
    return ok and ctx and ns.L.specs[ctx.specKey] or nil
end

function api.OnChange(fn) listeners[#listeners + 1] = fn end

Sendit.Provide("upgrade", api)

-- Gear and level are announced once the character has settled: the client sends the new stats and
-- level a moment after the event, and a set swap is a burst of events. Rated earlier = rated stale.
local SETTLE = 1.5
local pending, lastAt = false, 0
local function Settled()
    local wait = lastAt + SETTLE - GetTime()
    if wait > 0 then return C_Timer.After(wait, Settled) end
    pending = false
    ns.Compare.Invalidate()
    Changed()
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterUnitEvent("UNIT_STATS", "player")
events:SetScript("OnEvent", function(_, event)
    if event == "UNIT_STATS" and not pending then return end  -- buffs alone change nothing rated
    lastAt = GetTime()
    if pending then return end
    pending = true
    C_Timer.After(SETTLE, Settled)
end)
-- only the spec and enemy level count (settings change all the time elsewhere)
local lastKey ---@type string?
local function Key()
    return table.concat({ ns.charDB and ns.charDB.spec or "auto", ns.Settings.TargetDelta() }, "/")
end
Sendit.OnReady(function() lastKey = lastKey or Key() end)  -- so the first change of a session counts
Sendit.OnSettingsChanged(function()
    local key = Key()
    if lastKey and key ~= lastKey then Changed() end
    lastKey = key
end)
