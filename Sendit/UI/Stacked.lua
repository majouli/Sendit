--[[
  Stacked: the modules' big windows (maps, dungeons, quests, wardrobe, macros) may be open together; the one
  opened or clicked last lies in front, whole (equal strata and levels would mix their parts).
  Sendit.Widgets.Stacked(frame)   call once on the module's own window
]]
local _, ns = ...
local W = ns.Widgets

function W.Stacked(frame)
    frame:SetToplevel(true)  -- a click raises it
    frame:HookScript("OnShow", function(self) self:Raise() end)  -- our own frame
end
