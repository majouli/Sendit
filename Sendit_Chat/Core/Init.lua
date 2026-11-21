--[[
  Init: namespace, settings binding, event dispatch.
  ns.db = profile section (font, background, border, lock, chat / whisper / loot features),
  ns.acct = account section (on / off, window layout), ns.Design() = the core's design,
  ns.char = per character (Sendit_ChatCharDB: conversations, history).
  ns.Listen(event, fn);  ns.OnChanged(fn) / ns.Changed();  ns.OnReady(fn) (once, chat active only)
  Another addon with the chat (Conflict.Find): Sendit Chat stays off and asks to take over
  (TakeoverDialog) unless the player chose to keep that addon (acct.keepOther).
]]
local addonName, ns = ...
local Sendit = Sendit

ns.VERSION = C_AddOns and C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"

ns.defaults = {  -- profile section
    fontSize = 13,
    bgAlpha = 0.72,
    border = 1,           -- px, 0 = no border
    locked = false,
    splitWhispers = true, -- whispers live in the messenger, not in the main chat
    slashWhisper = true,  -- "/w name " typed in Blizzard's chat input opens the messenger on name
    friendsPanel = true,  -- the friends list beside the messenger (UI/FriendsPanel.lua)
    friendsCharClick = false, -- Battle.net friends in WoW: a click whispers the character
    whisperAlert = "toast", -- new whisper: "toast" (bubble above the chat), "open" (messenger), "off" (badge)
    lootStyle = true,     -- own loot lines restyled (icon, quality stripe, slot)
    lootCards = true,     -- a card glides in for own loot of lootCardQuality or better
    lootCardQuality = 3,  -- 3 = rare
    keepHistory = true,   -- chat lines survive /reload and logout (per character)
    shortChannels = true, -- "[1. General - Elwynn Forest]" -> "[1. General]"
    mentions = true,      -- your name in group/guild/public chat: gold, tab dot, sound
    rollSummary = true,   -- other players' roll choices/numbers dropped; the result sums them up
    rollArena = true,     -- live rolls above the chat: choices, numbers revealed one by one, /roll (Duels)
}

ns.acctDefaults = {  -- account section
    enabled = true,
    windows = {},         -- [1] = main; { point, x, y, w, h, minimized, selected, tabs (detached only) }
    tabs = {},            -- own tabs: { { id, name, take, kinds } } (Core/Tabs.lua)
    generalHide = {},     -- [kind / channel key] = true: switched off in General
    messenger = {},       -- { x, y, w, h, minimized }
    friendsOpen = true,   -- the friends panel is open beside the messenger
    friendFavorites = {}, -- [friend key] = true: pinned to the top of the friends list
    friendWatch = {},     -- [friend key] = true: a notice when they come online
}

ns.charDefaults = {
    version = 1,
    convs = {},           -- [key] = conversation, see Core/Whispers.lua
    history = {},         -- [tab index] = { { text, r, g, b }, ... } (UI/ChatWindow.lua)
}

local function Fill(t, defaults)
    for k, v in pairs(defaults) do
        if t[k] == nil then
            if type(v) == "table" then
                t[k] = {}
                Fill(t[k], v)
            else
                t[k] = v
            end
        end
    end
    return t
end
ns.Fill = Fill

ns.module = Sendit:RegisterModule({
    addon = "Sendit_Chat",
    key = "chat",
    title = "Chat",
    icon = "Interface\\AddOns\\Sendit_Chat\\Media\\Icon",
    defaults = ns.defaults,
    accountDefaults = ns.acctDefaults,
    -- 2: popupWhispers (boolean) became whisperAlert
    version = 2,
    migrate = function(section, from)
        if from < 2 and section.popupWhispers ~= nil then
            section.whisperAlert = section.popupWhispers and "toast" or "off"
            section.popupWhispers = nil
        end
    end,
    status = function()
        if ns.yielding then return "yielding" end
        return ns.active and "on" or "off"
    end,
})

local design = Sendit:Module("design")
function ns.Design() return design.profile end

local function Bind()
    ns.db, ns.acct = ns.module.profile, ns.module.db
end
Sendit.OnReady(Bind)
Sendit.OnProfile(Bind)

local listeners = {}
local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
    local list = listeners[event]
    if not list then return end
    for i = 1, #list do list[i](event, ...) end
end)

function ns.Listen(event, fn)
    if not listeners[event] then
        listeners[event] = {}
        frame:RegisterEvent(event)
    end
    local list = listeners[event]
    list[#list + 1] = fn
end

ns.OnChanged, ns.Changed = Sendit.OnSettingsChanged, Sendit.SettingsChanged

local ready = {}
function ns.OnReady(fn) ready[#ready + 1] = fn end

function ns.Print(msg)
    local cf = _G["DEFAULT_CHAT_FRAME"]
    if cf then cf:AddMessage("|cffe6ba66Sendit Chat|r " .. tostring(msg)) end
end

local function IsLoaded(name)
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name) and true or false
end

ns.Listen("ADDON_LOADED", function(_, name)
    if name ~= addonName then return end
    local char = type(Sendit_ChatCharDB) == "table" and Sendit_ChatCharDB or {}
    Sendit_ChatCharDB = Fill(char, ns.charDefaults)
    ns.char = Sendit_ChatCharDB
end)

ns.Listen("PLAYER_LOGIN", function()
    if not ns.acct then return end
    if not ns.acct.enabled then
        ns.Print(ns.L.DISABLED)
        return
    end
    ns.Conflict.OnFound(function(other)  -- an addon took the chat after the start
        if ns.active and ns.acct.keepOther ~= other then ns.TakeoverDialog.Show(other) end
    end)
    local other = ns.Conflict.Find()
    if other then
        ns.yielding = other
        if ns.acct.keepOther == other then
            ns.Print(ns.L.YIELD:format(ns.Conflict.Title(other)))
        else
            ns.TakeoverDialog.Show(other)
        end
        return
    end
    ns.active = true
    for i = 1, #ready do ready[i]() end
end)
