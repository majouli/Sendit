--[[
  Init: registers the Macros module, its launcher and /macros (its page: Page.lua).
  Account: showAll (unlearned macros in the list).
]]
local _, ns = ...
ns.module = Sendit:RegisterModule({
    key = "macros", title = "Macros", addon = "Sendit_Macros",
    icon = "Interface\\AddOns\\Sendit_Macros\\Media\\Icon",
    accountDefaults = { showAll = false },
})

Sendit:AddLauncher({
    module = ns.module,
    key = "macros", order = 60, icon = "Interface\\AddOns\\Sendit_Macros\\Media\\Icon", title = function() return ns.L.title end,
    toggle = function() ns.Window.Toggle() end,
    shown = function() return ns.Window.Shown() end,
})

SLASH_SENDITMACROS1 = "/macros"
SlashCmdList.SENDITMACROS = function() ns.Window.Toggle() end
