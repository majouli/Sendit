--[[
  Service: Upgrade's rating offered to the other Sendit modules (Sendit.Provide
  "upgrade"; the Quests journal's gear boost uses it). Same calculation as the
  tooltip: the item virtually equipped, the character recalculated for the
  chosen specialization (Compare.Evaluate).

  Sendit.Service("upgrade"):
    Rate(itemID) -> r
      r.status  "ok" | "loading" (item not cached yet: ask again later) |
                "unusable" | "equipped" | "noCompare" | "nodata" | "unsupported"
      r.pct     change of the spec's main metric in percent (status "ok")
      r.slotPct the gain against the worn item in that slot (nil: slot empty
                - r.empty - or its item adds nothing), r.equipLoc the slot type
      r.label   the metric's name ("Damage", "Healing", ...), r.unit
      r.secondaryPct / r.secondaryLabel  the spec's second metric (the
                tooltip's "but Survival -2.6 %" trade-off)
      r.gate    the item's required level when above the character's
    Spec() -> localized name of the specialization rated for
    OnChange(fn)  fn() when gear, level, the chosen specialization, or enemy
                  level change: ratings are stale (other settings do not count)
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
-- The specialization and enemy level are picked on Upgrade's page; settings change all the time elsewhere in the suite (Fade,
-- ...): only these count.
local lastKey ---@type string?
Sendit.OnSettingsChanged(function()
    local key = table.concat({ ns.charDB and ns.charDB.spec or "auto", ns.Settings.TargetDelta() }, "/")
    if lastKey and key ~= lastKey then Changed() end
    lastKey = key
end)
