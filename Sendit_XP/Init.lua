--[[
  Init: registers the Experience module.
  Profile: height (character point above the screen centre, px), size (bubble scale).
]]
local _, ns = ...
ns.module = Sendit:RegisterModule({
    key = "xp", title = "Experience", addon = "Sendit_XP",
    icon = "Interface\\AddOns\\Sendit_XP\\Media\\Icon",
    defaults = { height = -40, size = 1 },
})
