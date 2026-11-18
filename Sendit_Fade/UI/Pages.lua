--[[
  Pages: the General and Triggers pages of Fade in the Sendit window.
  Texts come from Locale.lua as functions (follow a language switch).
  Each row binds a widget to a setting through a getter and a setter.
]]
local _, ns = ...

local Options, W, L = ns.Options, ns.Widgets, ns.L
local SettingsPage = Options.SettingsPage
local function Tx(key) return Sendit.Locale.Text(L, key) end

-- Persisted setting changed: refresh everything (resync: rebuild fade set).
local function Changed(resync)
    if resync then ns.Fader:Sync() end
    ns.SettingsChanged()
end
ns.Changed = Changed

-- getter, setter for a top-level setting: the active profile's if it is a
-- profile key, the account's otherwise.
local function DB(key)
    local function Store() return ns.profileDefaults[key] ~= nil and ns.profile or ns.db end
    return function() return Store()[key] end, function(v) Store()[key] = v; Changed() end
end

local function Percent(v) return math.floor(v * 100 + 0.5) .. "%" end
local function Seconds(v) return ("%gs"):format(math.floor(v * 100 + 0.5) / 100) end

---------------------------------------------------------------------------
-- General
---------------------------------------------------------------------------
Options:Register({
    key = "fade.general",
    module = ns.module,
    title = Tx("GENERAL"),
    subtitle = Tx("GENERAL_SUB"),
    resetKeys = { "enabled", "alpha", "delay", "fadeOut", "fadeIn", "cinema", "cinemaCamera", "cinemaServices",
                  "cinemaWalkAway" },
    onReset = function() ns.Fader:Reset(); ns.Fader:Sync() end,
    build = SettingsPage(function(Lay, c)
        Lay:Section(Tx("FADING"))
        Lay:Row(Tx("ENABLE"), Tx("ENABLE_DESC"),
            W.Switch(c, function() return ns.profile.enabled end, function(v)
                ns.profile.enabled = v
                if v then ns.Fader:Reset() end
                Changed(true)
            end))
        local get, set = DB("alpha")
        Lay:Row(Tx("ALPHA"), Tx("ALPHA_DESC"), W.Slider(c, 0, 1, 0.05, get, set, Percent), 70)
        get, set = DB("delay")
        Lay:Row(Tx("DELAY"), Tx("DELAY_DESC"), W.Slider(c, 0, 30, 0.5, get, set, Seconds), 70)
        get, set = DB("fadeOut")
        Lay:Row(Tx("FADE_OUT"), Tx("FADE_OUT_DESC"), W.Slider(c, 0, 3, 0.1, get, set, Seconds), 70)
        get, set = DB("fadeIn")
        Lay:Row(Tx("FADE_IN"), Tx("FADE_IN_DESC"), W.Slider(c, 0, 1, 0.05, get, set, Seconds), 70)
        Lay:EndSection()

        Lay:Section(Tx("CINEMA"))
        get, set = DB("cinema")
        Lay:Row(Tx("CINEMA_ON"), function()
            return L.CINEMA_ON_DESC .. (ns.Cinema:HasSpoken() and "" or L.NEEDS_SPOKEN)
        end, W.Switch(c, get, set))
        get, set = DB("cinemaCamera")
        Lay:Row(Tx("ORBIT"), Tx("ORBIT_DESC"), W.Switch(c, get, set))
        get, set = DB("cinemaWalkAway")
        Lay:Row(Tx("WALK"), Tx("WALK_DESC"), W.Switch(c, get, set))
        get, set = DB("cinemaServices")
        Lay:Row(Tx("SERVICES"), Tx("SERVICES_DESC"), W.Switch(c, get, set))
        Lay:Row(Tx("PREVIEW"), Tx("PREVIEW_DESC"), W.Button(c, L.PREVIEW, function() ns.Cinema:Preview(8) end))
        Lay:EndSection()

        Lay:Section(Tx("INTERFACE"))
        Lay:Row(Tx("ICON"), Tx("ICON_DESC"),
            W.Switch(c, function() return ns.db.icon.show end, function(v)
                ns.db.icon.show = v
                Changed()
            end))
        Lay:Row(Tx("ICON_LOCK"), Tx("ICON_LOCK_DESC"),
            W.Switch(c, function() return ns.db.icon.locked end, function(v)
                ns.db.icon.locked = v
                Changed()
            end))
        Lay:Row(Tx("ICON_ALPHA"), Tx("ICON_ALPHA_DESC"),
            W.Slider(c, 0.1, 1, 0.05, function() return ns.db.icon.alpha end, function(v)
                ns.db.icon.alpha = v
                Changed()
            end, Percent), 70)
        get, set = DB("announce")
        Lay:Row(Tx("ANNOUNCE"), Tx("ANNOUNCE_DESC"), W.Switch(c, get, set))
        Lay:EndSection()
    end),
})

---------------------------------------------------------------------------
-- Triggers
---------------------------------------------------------------------------
local TRIGGERS = { "combat", "target", "health", "casting", "mouseover", "typing", "chatGroup", "chatLoot" }

Options:Register({
    key = "fade.triggers",
    module = ns.module,
    title = Tx("TRIGGERS"),
    subtitle = Tx("TRIGGERS_SUB"),
    resetKeys = { "triggers" },
    build = SettingsPage(function(Lay, c)
        Lay:Section(Tx("SHOW_WHEN"))
        for _, key in ipairs(TRIGGERS) do
            Lay:Row(Tx("T_" .. key), Tx("T_" .. key .. "_DESC"), W.Switch(c,
                function() return ns.profile.triggers[key] end,
                function(v) ns.profile.triggers[key] = v; Changed() end))
        end
        Lay:EndSection()

        Lay:Section(Tx("DIAGNOSTICS"))
        local get, set = DB("debug")
        Lay:Row(Tx("DEBUG"), Tx("DEBUG_DESC"), W.Switch(c, get, set))
        Lay:EndSection()
    end),
})
