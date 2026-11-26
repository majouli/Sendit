--[[
  Page: the Sell page in the Sendit window - the list at the merchant, when the auction house pays off
  (margin %, at least minGain silver), disenchanting for enchanters, a second spec whose upgrades are kept.
]]
local _, ns = ...
local L = ns.L
local O, W = Sendit.Options, Sendit.Widgets
local function Tx(key) return Sendit.Locale.Text(L, key) end

local function SpecChoices()
    local list = { { "none", L.none } }
    local up = Sendit.Service("upgrade")
    for _, s in ipairs(up and up.Specs and up.Specs() or {}) do list[#list + 1] = { s.key, s.name } end
    return list
end

local function Bind(key)
    return function() return ns.module.profile[key] end, function(v)
        ns.module.profile[key] = v
        Sendit.SettingsChanged()
        if ns.Window then ns.Window.Refresh() end
    end
end

O:Register({
    key = "sell",
    module = ns.module,
    title = Tx("title"),
    subtitle = Tx("subtitle"),
    resetKeys = { "autoOpen", "margin", "minGain", "disenchant", "minUpgrade", "secondSpec" },
    build = O.SettingsPage(function(Lay, c)
        Lay:Section(Tx("section"))
        Lay:Row(Tx("autoOpen"), Tx("autoOpenDesc"), W.Switch(c, Bind("autoOpen")))
        local get, set = Bind("margin")
        Lay:Row(Tx("margin"), Tx("marginDesc"), W.Slider(c, 0, 200, 10, get, set,
            function(v) return ("+%d%%"):format(v) end))
        get, set = Bind("minGain")
        Lay:Row(Tx("minGain"), Tx("minGainDesc"), W.Slider(c, 0, 500, 10, get, set,
            function(v) return ("%ds"):format(v) end))
        Lay:Row(Tx("disenchant"), Tx("disenchantDesc"), W.Switch(c, Bind("disenchant")))
        get, set = Bind("minUpgrade")
        Lay:Row(Tx("minUpgrade"), Tx("minUpgradeDesc"), W.Slider(c, 0, 5, 0.5, get, set,
            function(v) return (("%.1f%%"):format(v):gsub("%.", ns.L.decimal or ".", 1)) end))
        Lay:Row(Tx("secondSpec"), Tx("secondSpecDesc"), W.Dropdown(c, 200, SpecChoices,
            function() return ns.module.profile.secondSpec or "none" end,
            function(v)
                ns.module.profile.secondSpec = v ~= "none" and v or nil
                Sendit.SettingsChanged()
                if ns.Window then ns.Window.Refresh() end
            end))
        Lay:EndSection()
    end),
})
