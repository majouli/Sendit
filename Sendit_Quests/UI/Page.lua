--[[
  Page: a single entry in Sendit's settings/search opens the independent
  quest browser. No redundant settings or second minimap button.
]]
local _, ns = ...
local O, W = Sendit.Options, Sendit.Widgets
local function Tx(key) return Sendit.Locale.Text(ns.L, key) end
O:Register({
    key = "quests", module = ns.module, title = "Quests", subtitle = Tx("subtitle"),
    build = O.SettingsPage(function(Lay, content)
        Lay:Section("Quests")
        Lay:Row(Tx("page"), Tx("pageDesc"), W.Button(content, ns.L.open, function()
            O:Hide()
            ns.Window:Open()
        end))
        Lay:EndSection()
    end),
})
