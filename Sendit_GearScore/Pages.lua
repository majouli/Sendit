--[[
  Pages: the GearScore page of the Sendit window (replaces the old own
  window). Own score on top, then tooltips, windows and the known players.
  Switches write ns.db (the profile section) and call
  Sendit.SettingsChanged(); Panels.Apply re-places the frames live.
  Texts come from Locale.lua (five languages).
]]
local _, ns = ...
local L = ns.L

local Sendit = Sendit
local O, W = Sendit.Options, Sendit.Widgets
local Score = ns.Score
local function Tx(key) return Sendit.Locale.Text(L, key) end

local function Bind(key)
    return function() return ns.db[key] end, function(v) ns.db[key] = v; Sendit.SettingsChanged() end
end

local function KnownCount()
    local n = 0
    for _ in pairs(ns.data and ns.data.players or {}) do n = n + 1 end
    return math.max(0, n - 1)  -- the own entry is not "known players"
end

local function Own()
    local ok, r = pcall(Score.Unit, "player")
    if not ok or not r then return "" end
    return Score.Colored(r.score) .. "  |cff999999" .. L.itemLevel .. " " .. r.ilvl .. "|r"
end

O:Register({
    key = "gearscore",
    module = ns.module,
    title = Tx("gearScore"),
    subtitle = Tx("title"),
    resetKeys = { "itemTip", "playerTip", "auto", "charRow", "inspectPos" },
    build = O.SettingsPage(function(Lay, c)
        Lay:Section(Tx("gearScore"))
        Lay:Row(UnitName("player") or "GearScore", nil, W.Value(c, 220, Own))
        -- language-free button (the client's "pass" cross); the row says what it does
        local button = W.Button(c, "|TInterface\\Buttons\\UI-GroupLoot-Pass-Up:16|t", function()
            ns.commands.reset()
            Sendit.SettingsChanged()
        end)
        button:SetWidth(44)
        Lay:Row(function() return L.optForget:format(KnownCount()) end, nil, button)
        Lay:EndSection()

        Lay:Section(Tx("optTooltips"))
        local get, set = Bind("itemTip")
        Lay:Row(Tx("optItemTip"), Tx("optItemTipHint"), W.Switch(c, get, set))
        get, set = Bind("playerTip")
        Lay:Row(Tx("optPlayerTip"), Tx("optPlayerTipHint"), W.Switch(c, get, set))
        get, set = Bind("auto")
        Lay:Row(Tx("optAuto"), Tx("optAutoHint"), W.Switch(c, get, set))
        Lay:EndSection()

        Lay:Section(Tx("optWindows"))
        get, set = Bind("charRow")
        Lay:Row(Tx("optCharRow"), Tx("optCharRowHint"), W.Switch(c, get, set))
        get, set = Bind("inspectPos")
        Lay:Row(Tx("optInspectPos"), nil, W.Segmented(c, { { "top", Tx("posTop") }, { "bottom", Tx("posBottom") } }, get, set))
        Lay:EndSection()
    end),
})

-- The GearScore page; toggles when it is already on screen.
function ns.OpenSettings()
    local cur = O:Current()
    if cur and cur.module == ns.module then return O:Hide() end
    O:Show("gearscore")
end

-- Options -> frames, live.
Sendit.OnSettingsChanged(function()
    if ns.db and ns.Panels then ns.Panels.Apply() end
end)

ns.Inspect.OnChange(function(guid)
    if guid == ns.GUID("player") and O:Current() and O:Current().module == ns.module then O:Refresh() end
end)
