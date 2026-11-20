--[[
  Page: Upgrade's page - the rated spec (per character, auto = guessed from gear), the enemy level, and
  the compare window. No profile settings (these belong to the character).
]]
local _, ns = ...
local L = ns.L

local Sendit = Sendit
local O, W = Sendit.Options, Sendit.Widgets
local function Tx(key) return Sendit.Locale.Text(L, key) end

local function SpecChoices()
    local list = { { "AUTO", ns.AutoLabel() } }
    local _, class = UnitClass("player")
    local data = class and ns.Specs[class]
    for _, key in ipairs(data and data.order or {}) do list[#list + 1] = { key, L.specs[key] or key } end
    return list
end

local function TargetChoices()
    local list = { { 0, L.targetStandard } }
    for d = 1, ns.Settings.MAX_DELTA do list[#list + 1] = { d, L.targetAbove:format(d) } end
    return list
end

O:Register({
    key = "upgrade",
    module = ns.module,
    title = "Upgrade",
    subtitle = Tx("title"),
    build = O.SettingsPage(function(Lay, c)
        Lay:Section("Upgrade")
        Lay:Row(Tx("pageSpec"), Tx("pageSpecDesc"),
            W.Dropdown(c, 250, SpecChoices,
                function() return ns.charDB and ns.charDB.spec or "AUTO" end,
                function(v) ns.SetSpec(v ~= "AUTO" and v or nil) end))
        Lay:Row(Tx("pageTarget"), Tx("pageTargetDesc"),
            W.Dropdown(c, 250, TargetChoices,
                function() return ns.Settings.TargetDelta() end,
                function(v) ns.Settings.Set("targetDelta", v ~= 0 and v or nil) end))
        Lay:Row(Tx("pageWindow"), Tx("pageWindowDesc"),
            W.Button(c, L.pageOpen, function()
                O:Hide()
                ns.Window:Toggle()
            end))
        Lay:EndSection()
        Lay:Note(Tx("pageNote"))
    end),
})
