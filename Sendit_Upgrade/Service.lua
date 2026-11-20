--[[
  Service: Upgrade's rating for the other modules (Sendit.Provide "upgrade"), the tooltip's calculation.
  Rate(itemID) -> r = { status, pct, slotPct, empty, equipLoc, label, unit, secondaryPct,
                        secondaryLabel, gate }   status "ok" | "loading" | "unusable" | ...
  Spec() -> the rated specialization's name
  OnChange(fn)   gear, level, spec or enemy level changed: ratings are stale
]]
local _, ns = ...

local listeners = {}
local function Changed()
    for _, fn in ipairs(listeners) do pcall(fn) end
end

local api = {}

function api.Rate(itemID)
    local r = ns.Compare.Evaluate("item:" .. tostring(itemID))
    if not r then return { status = "noCompare" } end
    if r.status ~= "ok" then return { status = r.status } end
    return { status = "ok", pct = r.primary.pct, slotPct = r.primary.slotPct, empty = r.primary.slotEmpty,
        label = r.primary.label, secondaryPct = r.secondary and r.secondary.pct,
        secondaryLabel = r.secondary and r.secondary.label,
        unit = r.primary.unit, gate = r.levelGate, equipLoc = r.item and r.item.equipLoc }
end

function api.Spec()
    local ok, ctx = pcall(ns.Compare.Context)
    return ok and ctx and ns.L.specs[ctx.specKey] or nil
end

function api.OnChange(fn) listeners[#listeners + 1] = fn end

Sendit.Provide("upgrade", api)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", Changed)
-- only the spec and enemy level count (settings change all the time elsewhere)
local lastKey ---@type string?
Sendit.OnSettingsChanged(function()
    local key = table.concat({ ns.charDB and ns.charDB.spec or "auto", ns.Settings.TargetDelta() }, "/")
    if lastKey and key ~= lastKey then Changed() end
    lastKey = key
end)
