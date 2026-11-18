--[[
  Settings: the model choice a player can make on the Upgrade page, per
  character (Sendit_UpgradeCharDB), "Standard" first - the model's default,
  picked when nothing is saved.
    targetDelta  levels the rated enemy is above the character: 0 (standard:
                 own level) .. 3; higher enemies make hit worth more (Model.Target)
  (Damage over time crits is no choice: on Forever it always can - Model.Cast.)
  Contract: Settings.TargetDelta() -> 0..3,
            Settings.Set(key, value) saves and re-rates (nil = standard).
]]
local _, ns = ...

local Settings = {}
ns.Settings = Settings
Settings.MAX_DELTA = 3

function Settings.TargetDelta()
    local d = ns.charDB and tonumber(ns.charDB.targetDelta) or 0
    return math.max(0, math.min(Settings.MAX_DELTA, math.floor(d)))
end

function Settings.Set(key, value)
    if not ns.charDB then return end
    ns.charDB[key] = value
    ns.Compare.Invalidate()
    if ns.Window then ns.Window:Refresh() end
    Sendit.SettingsChanged()
end
