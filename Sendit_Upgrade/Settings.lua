--[[
  Settings: the model choice on the Upgrade page, per character (Sendit_UpgradeCharDB), standard first.
  targetDelta = levels the rated enemy is above you, 0..3 (higher makes hit worth more).
  Settings.TargetDelta() -> 0..3;  Settings.Set(key, value) saves and re-rates (nil = standard)
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
