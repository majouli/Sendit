--[[
  Init: registers the Macros module, its launcher and /macros. No settings page: the window is the module.
  Account: showAll (unlearned macros in the list).
]]
local _, ns = ...
ns.module = Sendit:RegisterModule({
    key = "macros", title = "Macros", addon = "Sendit_Macros",
    icon = "Interface\\Icons\\INV_Misc_Book_09",
    accountDefaults = { showAll = false },
})

Sendit:AddLauncher({
    key = "macros", order = 60, icon = "Interface\\Icons\\INV_Misc_Book_09", title = function() return ns.L.title end,
    toggle = function() ns.Window.Toggle() end,
    shown = function() return ns.Window.Shown() end,
})

SLASH_SENDITMACROS1 = "/macros"
SlashCmdList.SENDITMACROS = function() ns.Window.Toggle() end
