--[[
  Pages: the Chat page (what only the chat has; the look is on Sendit's Design page); controls write
  ns.db / ns.acct and call ns.Changed(). The main window's gear opens it (ns.OpenSettings).
]]
local _, ns = ...

local Sendit = Sendit
local O, W = Sendit.Options, Sendit.Widgets
local T_ = ns.L
local function Tx(key) return Sendit.Locale.Text(T_, key) end

local function Bind(key)
    return function() return ns.db[key] end, function(v) ns.db[key] = v; ns.Changed() end
end

local function Percent(v) return math.floor(v * 100 + 0.5) .. "%" end

local function Quality(v)
    local name = Sendit.Locale.Global("ITEM_QUALITY" .. v .. "_DESC") or tostring(v)
    local r, g, b = ns.Loot.QualityRGB(v)
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), name)
end

O:Register({
    key = "chat",
    module = ns.module,
    title = "Chat",
    subtitle = Tx("PAGE_SUB"),
    resetKeys = { "fontSize", "bgAlpha", "border", "locked", "splitWhispers", "whisperAlert", "slashWhisper", "friendsPanel", "friendsCharClick", "lootStyle",
                  "lootCards", "lootCardQuality", "keepHistory", "shortChannels", "mentions", "rollSummary", "rollArena" },
    build = O.SettingsPage(function(L, c)
        L:Section(Tx("SEC_WINDOWS"))
        local get, set = Bind("fontSize")
        L:Row(Tx("FONT_SIZE"), Tx("FONT_SIZE_DESC"),
            W.Slider(c, 8, 24, 1, get, set, function(v) return v .. " pt" end), 70)
        get, set = Bind("bgAlpha")
        L:Row(Tx("BACKGROUND"), Tx("BACKGROUND_DESC"), W.Slider(c, 0, 1, 0.05, get, set, Percent), 70)
        get, set = Bind("border")
        L:Row(Tx("BORDER"), Tx("BORDER_DESC"),
            W.Slider(c, 0, 4, 1, get, set, function(v) return v .. " px" end), 70)
        get, set = Bind("locked")
        L:Row(Tx("LOCK"), Tx("LOCK_DESC"), W.Switch(c, get, set))
        L:Row(Tx("OWN_TABS"), Tx("OWN_TABS_DESC"),
            W.Button(c, T_.NEW_TAB, function()
                O:Hide()
                ns.TabEditor.Open()
            end))
        L:EndSection()

        L:Section(Tx("SEC_CHAT"))
        get, set = Bind("keepHistory")
        L:Row(Tx("KEEP_HISTORY"), Tx("KEEP_HISTORY_DESC"), W.Switch(c, get, set))
        get, set = Bind("shortChannels")
        L:Row(Tx("SHORT_CHANNELS"), Tx("SHORT_CHANNELS_DESC"), W.Switch(c, get, set))
        get, set = Bind("mentions")
        L:Row(Tx("MENTIONS"), Tx("MENTIONS_DESC"),
            W.Switch(c, get, set))
        L:EndSection()

        L:Section(Tx("SEC_WHISPERS"))
        get, set = Bind("splitWhispers")
        L:Row(Tx("SPLIT_WHISPERS"), Tx("SPLIT_WHISPERS_DESC"), W.Switch(c, get, set))
        get, set = Bind("whisperAlert")
        L:Row(Tx("WHISPER_ALERT"), Tx("WHISPER_ALERT_DESC"), W.Dropdown(c, 200, function()
            return { { "toast", T_.ALERT_TOAST }, { "open", T_.ALERT_OPEN }, { "off", T_.ALERT_OFF } }
        end, get, set))
        get, set = Bind("slashWhisper")
        L:Row(Tx("SLASH_WHISPER"), Tx("SLASH_WHISPER_DESC"), W.Switch(c, get, set))
        get, set = Bind("friendsPanel")
        L:Row(Tx("FRIENDS_PANEL"), Tx("FRIENDS_PANEL_DESC"), W.Switch(c, get, set))
        get, set = Bind("friendsCharClick")
        L:Row(Tx("FRIENDS_CHAR_CLICK"), Tx("FRIENDS_CHAR_CLICK_DESC"), W.Switch(c, get, set))
        L:EndSection()

        L:Section(Tx("SEC_LOOT"))
        get, set = Bind("lootStyle")
        L:Row(Tx("LOOT_STYLE"), Tx("LOOT_STYLE_DESC"), W.Switch(c, get, set))
        get, set = Bind("rollSummary")
        L:Row(Tx("ROLL_SUMMARY"), Tx("ROLL_SUMMARY_DESC"), W.Switch(c, get, set))
        get, set = Bind("rollArena")
        L:Row(Tx("ROLL_ARENA"), Tx("ROLL_ARENA_DESC"), W.Switch(c, get, set))
        get, set = Bind("lootCards")
        L:Row(Tx("LOOT_CARDS"), Tx("LOOT_CARDS_DESC"), W.Switch(c, get, set))
        get, set = Bind("lootCardQuality")
        L:Row(Tx("LOOT_CARD_QUALITY"), Tx("LOOT_CARD_QUALITY_DESC"), W.Slider(c, 2, 5, 1, get, set, Quality), 70)
        L:EndSection()
    end),
})

function ns.OpenSettings()
    local cur = O:Current()
    if cur and cur.module == ns.module then return O:Hide() end
    O:Show("chat")
end
