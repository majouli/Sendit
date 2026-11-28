--[[
  Page: the Maps page in the Sendit window - the map window, the map key in instances, other levels.
]]
local _, ns = ...
local L = ns.L
local O, W = Sendit.Options, Sendit.Widgets
local function Tx(key) return Sendit.Locale.Text(L, key) end

local function Bind(key)
    return function() return ns.module.profile[key] ~= false end, function(on)
        ns.module.profile[key] = on
        Sendit.SettingsChanged()
    end
end

O:Register({
    key = "maps",
    module = ns.module,
    title = Tx("title"),
    subtitle = Tx("subtitle"),
    resetKeys = { "mapKey", "others", "overlay", "mapStyle" },
    build = O.SettingsPage(function(Lay, c)
        Lay:Section(Tx("title"))
        Lay:Row(Tx("style"), Tx("styleDesc"), W.Segmented(c, { { "drawn", Tx("styleDrawn") }, { "blizzard", Tx("styleBlizzard") },
            { "rooms", Tx("styleRooms") } },
            function() return ns.Catalog.Style() end,
            function(v)
                ns.module.profile.mapStyle = v
                Sendit.SettingsChanged()
            end))
        Lay:Row(Tx("pageWindow"), Tx("pageWindowDesc"), W.Button(c, Tx("pageOpen"), function()
            O:Hide()
            ns.Window.Open()
        end))
        Lay:Row(Tx("mapKey"), Tx("mapKeyDesc"), W.Switch(c, Bind("mapKey")))
        Lay:Row(Tx("others"), Tx("othersDesc"), W.Switch(c, Bind("others")))
        Lay:Row(Tx("overlay"), Tx("overlayDesc"), W.Switch(c, function() return ns.module.profile.overlay == true end,
            function(on)
                ns.module.profile.overlay = on
                Sendit.SettingsChanged()
            end))
        Lay:EndSection()
    end),
})
