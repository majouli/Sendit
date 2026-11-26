--[[
  Page: the Experience page in the Sendit window - character height, bubble size, a preview.
]]
local _, ns = ...
local L = ns.L
local O, W = Sendit.Options, Sendit.Widgets
local function Tx(key) return Sendit.Locale.Text(L, key) end

local function Bind(key)
    return function() return ns.module.profile[key] end, function(v)
        ns.module.profile[key] = v
        Sendit.SettingsChanged()
    end
end

local function Preview()
    local now = ns.Gain.Read()
    local max = now and now.max or 2000
    ns.Burst.Play(math.floor(max * 0.06 + 0.5), max)
end

O:Register({
    key = "xp",
    module = ns.module,
    title = Tx("title"),
    subtitle = Tx("subtitle"),
    resetKeys = { "height", "size" },
    build = O.SettingsPage(function(Lay, c)
        Lay:Section(Tx("effect"))
        local get, set = Bind("height")
        Lay:Row(Tx("height"), Tx("heightDesc"), W.Slider(c, -300, 300, 10, get, set))
        get, set = Bind("size")
        Lay:Row(Tx("size"), nil, W.Slider(c, 0.6, 1.8, 0.1, get, set,
            function(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end))
        Lay:Row(Tx("preview"), Tx("previewDesc"), W.Button(c, L.play, Preview))
        Lay:EndSection()
    end),
})
