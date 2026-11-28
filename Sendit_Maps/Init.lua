--[[
  Init: registers the Maps module (dungeon and raid maps), its launcher and /maps.
  Profile: mapKey (inside an instance the world map key opens this map), others (other levels shown faint),
    overlay (the compact map inside instances), mapStyle ("drawn": the rooms in the drawn look |
    "blizzard": the client's drawn maps where they exist | "rooms": the room pictures).
  Account: window = { point }, overlay = { point, zoom }.
  Service "maps": Has(instanceMapID), Open(instanceMapID).
]]
local _, ns = ...

ns.ICON = "Interface\\Icons\\INV_Misc_Map_01"

ns.module = Sendit:RegisterModule({
    key = "maps", title = "Maps", addon = "Sendit_Maps", icon = ns.ICON,
    defaults = { mapKey = true, others = true, overlay = false, mapStyle = "drawn" },
    accountDefaults = { window = {} },
})

Sendit:AddLauncher({
    module = ns.module,
    key = "maps", order = 35, icon = ns.ICON, title = function() return ns.L.title end,
    toggle = function() ns.Window.Toggle() end,
    shown = function() return ns.Window.Shown() end,
})

-- for the dungeon browser's map button
Sendit.Provide("maps", {
    Has = function(id) return ns.Catalog.Has(id) end,
    Open = function(id) ns.Window.Open(id) end,
})

SLASH_SENDITMAPS1 = "/maps"
SlashCmdList.SENDITMAPS = function(msg)
    local what = (msg or ""):lower():match("^%s*probe%s*(%a*)")
    if what then return ns.Probe(what) end
    ns.Window.Toggle()
end
