--[[
  Page: Sendit's settings/search entry: opens the independent quest browser;
  switches the quest route beside Blizzard's quest log (account: route).
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
        Lay:Row(Tx("routeSetting"), Tx("routeSettingDesc"), W.Switch(content,
            function() return ns.module.db == nil or ns.module.db.route ~= false end,
            function(on)
                if ns.module.db then ns.module.db.route = on and true or false end
                Sendit.SettingsChanged()
            end))
        Lay:EndSection()
    end),
})
