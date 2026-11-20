--[[
  BoostDialog: Quests' settings for the suite's boost dialog (Sendit.BoostDialog) - plus the switch for
  locked chain steps; preview 0 / +1 / +2 / +3 / +5 levels.
  BoostDialog.Toggle(anchor, onStart, onEnd) / Hide() / IsShown() / Panel()
]]
local _, ns = ...
local L = ns.L
local Dialog = {}
ns.BoostDialog = Dialog
local Core = Sendit.BoostDialog
local AHEAD = { { 0, "0" }, { 1, "+1" }, { 2, "+2" }, { 3, "+3" }, { 5, "+5" } }
local cfg

function Dialog.Hide() Core.Hide() end
function Dialog.IsShown() return Core.IsShown() end
function Dialog.Panel() return Core.Panel() end

function Dialog.Toggle(anchor, onStart, onEnd)
    cfg = cfg or { L = L, boost = ns.Boost, ahead = AHEAD,
        switch = { get = function() return ns.Boost.Locked() end, set = function(on) ns.Boost.SetLocked(on) end },
        onChange = function(what)
            if what == "ahead" and ns.Boost.Active() then ns.Boost.Start() end  -- other quests count now
            if ns.Window then ns.Window:BoostChanged() end
        end }
    cfg.switch.text = L.boostLocked
    cfg.onStart, cfg.onEnd = onStart, onEnd
    Core.Toggle(anchor, cfg)
end
