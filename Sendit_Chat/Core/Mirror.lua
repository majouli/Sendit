--[[
  Mirror: Blizzard's chat frames stay the data plane, Sendit Chat shows the lines.

  Blizzard's chat frames keep all their events: their secure handler does
  class colours, player links, channel prefixes, censoring, other addons'
  message filters, the reply target (R) and the whisper sound. Every line
  they add is forwarded to Sendit Chat through a hooksecurefunc post-hook on
  AddMessage (the hook body only touches Sendit Chat's frames). Secret lines
  (chat lockdown) are forwarded whole; AddMessage of our own
  ScrollingMessageFrame accepts them.

  Mirror.Indices()          Blizzard window indices Sendit Chat shows as tabs
                            (the combat log too: its lines come through
                            AddMessage like any other)
  Mirror.Name(index)        tab label (Blizzard's default names in the suite language)
  Mirror.IsCombatLog(index) true for Blizzard's combat log window
  Mirror.ChatType(infoID)   Blizzard's chat type ("SAY", "CHANNEL5", ...) for a
                            line's info.id; nil when unknown
  Mirror.SetCombatReset(fn) fn("clear") / fn("back", text, r, g, b): a combat
                            log filter change clears Blizzard's log and fills
                            it again oldest-first with BackFillMessage
  Mirror.SetSink(fn)        fn(index, text, r, g, b, isWhisper, event, infoID);
                            lines that arrived earlier are replayed first
  Mirror.Hush()             makes Blizzard's chat visuals invisible and
                            click-through (alpha, mouse and hyperlinks only:
                            never Hide, reparent or field writes on Blizzard
                            frames, those taint the secure chat handler).
                            Hyperlinks too: ChatFrame1 sits above our window
                            and its invisible links took clicks even with
                            the mouse off (a click on our item link hit a
                            hidden player / channel link, seen in game).
  Mirror.EditBoxes()        Blizzard's permanent chat edit boxes
]]
local addonName, ns = ...
local Safe = ns.Safe

local Mirror = {}
ns.Mirror = Mirror

local BUFFER_MAX = 300
local WHISPER_EVENTS = {
    CHAT_MSG_WHISPER = true, CHAT_MSG_WHISPER_INFORM = true,
    CHAT_MSG_BN_WHISPER = true, CHAT_MSG_BN_WHISPER_INFORM = true,
}

local function NumWindows() return _G["NUM_CHAT_WINDOWS"] or 10 end
local function Frame(i) return _G["ChatFrame" .. i] end

function Mirror.IsCombatLog(i)
    local cf = Frame(i)
    return cf ~= nil and cf == _G["COMBATLOG"]
end

function Mirror.Name(i)
    local fn = _G["GetChatWindowInfo"]
    local name = fn and Safe.Str((fn(i)))
    if not name or name == "" then
        if i ~= 1 then return "Chat " .. i end
        name = "General"
    end
    return ns.DefaultName(name, "TAB_")  -- Blizzard's default names in the suite language
end

function Mirror.Indices()
    local list = {}
    local info = _G["GetChatWindowInfo"]
    for i = 1, NumWindows() do
        if Frame(i) then
            -- shown (boolean) or docked (dock position) = the window is in use
            local use = true
            if info then
                local _, _, _, _, _, _, shown, _, docked = info(i)
                use = (shown and true or false) or docked ~= nil and docked ~= false and docked ~= 0
            end
            if i == 1 or use then list[#list + 1] = i end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Whisper detection
---------------------------------------------------------------------------
-- info.id -> chat type. The ids are fixed per session: the map is built on
-- the first line and again on a miss (each miss id only once).
local typeOf = {}
function Mirror.ChatType(infoID)
    local id = Safe.Num(infoID)
    if not id then return nil end
    if typeOf[id] == nil then
        local info = _G["ChatTypeInfo"]
        if type(info) == "table" then
            for chatType, t in pairs(info) do
                local tid = type(t) == "table" and Safe.Num(t.id)
                if tid then typeOf[tid] = chatType end
            end
        end
        if typeOf[id] == nil then typeOf[id] = false end
    end
    return typeOf[id] or nil
end

-- The line's event ("CHAT_MSG_LOOT", ...): the event argument when the
-- client passes one, else derived from the chat type id.
local function EventOf(infoID, event)
    local e = Safe.Str(event)
    if e then return e end
    local chatType = Mirror.ChatType(infoID)
    return chatType and ("CHAT_MSG_" .. chatType) or nil
end
Mirror._EventOf = EventOf

local function IsWhisper(event) return event ~= nil and WHISPER_EVENTS[event] == true end

---------------------------------------------------------------------------
-- Line flow
---------------------------------------------------------------------------
local sink
local buffer = {}  -- lines before the sink exists: { index, text, r, g, b, whisper, event, infoID }

local function Forward(index, text, r, g, b, infoID, event)
    event = EventOf(infoID, event)
    local whisper = IsWhisper(event)
    if sink then
        sink(index, text, r, g, b, whisper, event, infoID)
    elseif #buffer < BUFFER_MAX then
        buffer[#buffer + 1] = { index, text, r, g, b, whisper, event, infoID }
    end
end

function Mirror.SetSink(fn)
    sink = fn
    local old = buffer
    buffer = {}
    for _, l in ipairs(old) do fn(l[1], l[2], l[3], l[4], l[5], l[6], l[7], l[8]) end
end

local hooked, resetHooked = {}, {}
local combatReset
function Mirror.SetCombatReset(fn) combatReset = fn end

local function HookCombatReset(cf)
    if resetHooked[cf] or cf ~= _G["COMBATLOG"] then return end
    resetHooked[cf] = true
    hooksecurefunc(cf, "Clear", function() if combatReset then combatReset("clear") end end)
    if type(cf.BackFillMessage) == "function" then
        hooksecurefunc(cf, "BackFillMessage", function(_, text, r, g, b)
            if combatReset and text ~= nil then combatReset("back", text, r, g, b) end
        end)
    end
end

-- Lines Blizzard added before Sendit Chat loaded (oldest first).
local function Backfill(i, cf)
    if not cf.GetNumMessages or not cf.GetMessageInfo then return end
    local n = Safe.Num(Safe.Call(cf.GetNumMessages, cf)) or 0
    for k = 1, n do
        local ok, text, r, g, b, infoID, _, _, event = pcall(cf.GetMessageInfo, cf, k)
        if ok and text ~= nil then Forward(i, text, r, g, b, infoID, event) end
    end
end

function Mirror.HookAll()
    for i = 1, NumWindows() do
        local cf = Frame(i)
        if cf and not hooked[cf] and type(cf.AddMessage) == "function" then
            hooked[cf] = true
            Backfill(i, cf)
            hooksecurefunc(cf, "AddMessage", function(_, text, r, g, b, infoID, _, _, event)
                if text == nil then return end
                Forward(i, text, r, g, b, infoID, event)
            end)
        end
        if cf then HookCombatReset(cf) end
    end
end

---------------------------------------------------------------------------
-- Hushing Blizzard's visuals
---------------------------------------------------------------------------
local SOCIAL_BUTTONS = {
    "QuickJoinToastButton", "ChatFrameMenuButton", "ChatFrameChannelButton",
    "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton",
    "CombatLogQuickButtonFrame_Custom",  -- the combat log's filter bar
}

local function AlphaZero(obj)
    if not obj or not obj.SetAlpha then return end
    local a = Safe.Call(obj.GetAlpha, obj)
    if a == nil or Safe.IsSecret(a) or a ~= 0 then pcall(obj.SetAlpha, obj, 0) end
end

local function MouseOff(obj)
    if not obj then return end
    if obj.EnableMouse then pcall(obj.EnableMouse, obj, false) end
    if obj.EnableMouseWheel then pcall(obj.EnableMouseWheel, obj, false) end
end

local function LinksOff(cf)
    if not cf.SetHyperlinksEnabled then return end
    local on = cf.GetHyperlinksEnabled and Safe.Call(cf.GetHyperlinksEnabled, cf)
    if on == false then return end
    pcall(cf.SetHyperlinksEnabled, cf, false)
end

local function Children(obj)
    if not obj.GetChildren then return {} end
    local ok, list = pcall(function() return { obj:GetChildren() } end)
    return ok and list or {}
end

-- Mouse off for a frame and its descendants, except the edit boxes.
local editBoxSet = {}
local function MouseOffTree(obj, depth)
    if not obj or editBoxSet[obj] or depth > 6 then return end
    MouseOff(obj)
    for _, c in ipairs(Children(obj)) do
        if type(c) == "table" then MouseOffTree(c, depth + 1) end
    end
end

local function TabRegionsOff(tab)
    if not tab or not tab.GetRegions then return end
    local ok, regions = pcall(function() return { tab:GetRegions() } end)
    if not ok then return end
    for _, r in ipairs(regions) do AlphaZero(r) end
end

function Mirror.EditBoxes()
    local list = {}
    for i = 1, NumWindows() do
        local eb = _G["ChatFrame" .. i .. "EditBox"]
        if eb then list[#list + 1] = eb end
    end
    return list
end

local function ChatFrameNames()
    local names = {}
    local frames = _G["CHAT_FRAMES"]
    if type(frames) == "table" then
        for _, n in ipairs(frames) do if type(n) == "string" then names[#names + 1] = n end end
    end
    if #names == 0 then
        for i = 1, NumWindows() do names[#names + 1] = "ChatFrame" .. i end
    end
    return names
end

function Mirror.Hush()
    for _, eb in ipairs(Mirror.EditBoxes()) do editBoxSet[eb] = true end
    for _, name in ipairs(ChatFrameNames()) do
        local cf = _G[name]
        if cf then
            local eb = _G[name .. "EditBox"]
            if eb then
                editBoxSet[eb] = true
                if eb.SetIgnoreParentAlpha then pcall(eb.SetIgnoreParentAlpha, eb, true) end
            end
            AlphaZero(cf)
            MouseOffTree(cf, 0)
            LinksOff(cf)
            local tab = _G[name .. "Tab"]
            if tab then
                MouseOff(tab)
                TabRegionsOff(tab)
            end
        end
    end
    local dock = _G["GeneralDockManager"]
    if dock then
        AlphaZero(dock)
        MouseOffTree(dock, 0)
    end
    for _, n in ipairs(SOCIAL_BUTTONS) do
        local b = _G[n]
        if b then AlphaZero(b); MouseOff(b) end
    end
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
ns.Listen("ADDON_LOADED", function(_, name)
    if name ~= addonName or not ns.acct or not ns.acct.enabled then return end
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("EllesmereUIChat") then return end
    Mirror.HookAll()
end)

local function Sweep()
    if not ns.active then return end
    Mirror.HookAll()  -- windows Blizzard created since
    Mirror.Hush()
    C_Timer.After(2, Sweep)
end

ns.OnReady(function()
    Sweep()
    local function Again() if ns.active then Mirror.HookAll(); Mirror.Hush() end end
    ns.Listen("UPDATE_CHAT_WINDOWS", Again)
    ns.Listen("UPDATE_FLOATING_CHAT_WINDOWS", Again)
    ns.Listen("PLAYER_ENTERING_WORLD", Again)
end)
