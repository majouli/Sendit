--[[
  Page: the Macros page in the Sendit window - the macro window and whether it lists macros not learned
  yet (account: ns.module.db.showAll, the same switch as in the window).
]]
local _, ns = ...
local L = ns.L
local O, W = Sendit.Options, Sendit.Widgets
local function Tx(key) return Sendit.Locale.Text(L, key) end

O:Register({
    key = "macros",
    module = ns.module,
    title = Tx("title"),
    subtitle = Tx("subtitle"),
    build = O.SettingsPage(function(Lay, c)
        Lay:Section(Tx("title"))
        Lay:Row(Tx("pageWindow"), Tx("pageWindowDesc"), W.Button(c, L.pageOpen, function()
            O:Hide()
            ns.Window.Open()
        end))
        Lay:Row(Tx("showAll"), Tx("pageShowAllDesc"), W.Switch(c, function() return ns.module.db.showAll end,
            function(on)
                ns.module.db.showAll = on
                if ns.Window.Shown() then ns.Window.Refresh() end
            end))
        Lay:EndSection()
    end),
})
