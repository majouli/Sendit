--[[
  Page: a single entry in Sendit's settings / search opens the dungeon
  browser. No settings of its own: filter and boost live in the window.
]]
local _, ns = ...
local O, W = Sendit.Options, Sendit.Widgets
local function Tx(key) return Sendit.Locale.Text(ns.L, key) end
O:Register({
    key = "dungeons", module = ns.module, title = "Dungeons", subtitle = Tx("subtitle"),
    build = O.SettingsPage(function(Lay, content)
        Lay:Section("Dungeons")
        Lay:Row(Tx("page"), Tx("pageDesc"), W.Button(content, ns.L.open, function()
            O:Hide()
            ns.Window:Open()
        end))
        Lay:EndSection()
    end),
})
