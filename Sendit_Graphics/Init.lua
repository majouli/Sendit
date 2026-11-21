--[[
  Init: registers the Graphics module.
  Profile: normal / raid = { [cvar] = value } - the values set on the page (see CVars).
  SenditGraphicsDB.probe: the engine limits /sendit graphics probe measured.
]]
local _, ns = ...
ns.module = Sendit:RegisterModule({
    key = "graphics", title = "Graphics", addon = "Sendit_Graphics",
    icon = "Interface\\AddOns\\Sendit_Graphics\\Media\\Icon",
    defaults = { normal = {}, raid = {} },
})

Sendit.OnModuleSwitch(function(addon, on)
    if addon == "Sendit_Graphics" then ns.disabled = not on end
end)
