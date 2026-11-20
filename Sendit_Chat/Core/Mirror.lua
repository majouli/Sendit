--[[
  Mirror: Blizzard's chat frames stay the data plane - their secure handler does colours, links,
  censoring, other addons' filters, reply target and sound; every line is forwarded through a
  hooksecurefunc post-hook on AddMessage (secret lines whole).
  Mirror.Indices() / Name(index) / IsCombatLog(index) / ChatType(infoID, r, g, b) / ChatTypes(infoID)
  Mirror.Refresh() / SharedIDs() / SetCombatReset(fn) / SetSink(fn) / EditBoxes()
  Mirror.Hush(): Blizzard's chat visuals invisible and click-through - alpha, mouse and hyperlinks
  only; never Hide, reparent or field writes (those taint the secure chat handler).
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
            -- shown or docked = the window is in use
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

-- info.id -> chat types; several types can share an id: then the line's colour decides
-- pairs(ChatTypeInfo) yields nothing in this client: types are looked up by name
local KNOWN_TYPES = {
    "SYSTEM", "SAY", "PARTY", "RAID", "GUILD", "OFFICER", "GUILD_DISCORD", "YELL", "WHISPER",
    "SMART_WHISPER", "WHISPER_INFORM", "REPLY", "EMOTE", "TEXT_EMOTE", "MONSTER_SAY", "MONSTER_PARTY",
    "MONSTER_YELL", "MONSTER_WHISPER", "MONSTER_EMOTE", "CHANNEL", "CHANNEL_JOIN", "CHANNEL_LEAVE",
    "CHANNEL_LIST", "CHANNEL_NOTICE", "CHANNEL_NOTICE_USER", "TARGETICONS", "AFK", "DND", "IGNORED",
    "SKILL", "LOOT", "CURRENCY", "MONEY", "OPENING", "TRADESKILLS", "PET_INFO", "COMBAT_MISC_INFO",
    "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "COMBAT_FACTION_CHANGE", "BG_SYSTEM_NEUTRAL",
    "BG_SYSTEM_ALLIANCE", "BG_SYSTEM_HORDE", "RAID_LEADER", "RAID_WARNING", "RAID_BOSS_WHISPER",
    "RAID_BOSS_EMOTE", "QUEST_BOSS_EMOTE", "ENCOUNTER_EVENT", "FILTERED", "INSTANCE_CHAT",
    "INSTANCE_CHAT_LEADER", "RESTRICTED", "ACHIEVEMENT", "GUILD_ACHIEVEMENT", "GUILD_ITEM_LOOTED",
    "PARTY_LEADER", "BN_WHISPER", "BN_WHISPER_INFORM", "BN_ALERT", "BN_BROADCAST",
    "BN_BROADCAST_INFORM", "BN_INLINE_TOAST_ALERT", "BN_INLINE_TOAST_BROADCAST",
    "BN_INLINE_TOAST_BROADCAST_INFORM", "BN_WHISPER_PLAYER_OFFLINE", "PET_BATTLE_COMBAT_LOG",
    "PET_BATTLE_INFO", "COMMUNITIES_CHANNEL", "VOICE_TEXT", "COLLECTED_APPEARANCE", "PING",
}

local typesOf = {}
local function Rebuild()
    wipe(typesOf)
    local info = _G["ChatTypeInfo"]
    if type(info) ~= "table" then return end
    local seen = {}
    local function Add(chatType)
        if seen[chatType] then return end
        seen[chatType] = true
        local t = info[chatType]
        local tid = type(t) == "table" and Safe.Num(t.id)
        if tid then
            typesOf[tid] = typesOf[tid] or {}
            table.insert(typesOf[tid], chatType)
        end
    end
    for _, chatType in ipairs(KNOWN_TYPES) do Add(chatType) end
    for n = 1, _G["MAX_WOW_CHAT_CHANNELS"] or 20 do Add("CHANNEL" .. n) end
    for chatType in pairs(info) do
        if type(chatType) == "string" then Add(chatType) end
    end
    for _, list in pairs(typesOf) do table.sort(list) end
end

-- ids are set once Blizzard's chat settings loaded: a miss rebuilds the map (once a second)
local builtAt
local function Candidates(id)
    if typesOf[id] == nil then
        local now = GetTime()
        if not builtAt or now - builtAt >= 1 then
            builtAt = now
            Rebuild()
        end
    end
    return typesOf[id]
end

function Mirror.Refresh()
    builtAt = GetTime()
    Rebuild()
end

local function Near(a, b) return a and b and math.abs(a - b) < 0.004 end

function Mirror.ChatType(infoID, r, g, b)
    local id = Safe.Num(infoID)
    if not id then return nil end
    local list = Candidates(id)
    if not list then return nil end
    if #list == 1 then return list[1] end
    r, g, b = Safe.Num(r), Safe.Num(g), Safe.Num(b)
    if not (r and g and b) then return nil end
    local info, hit = _G["ChatTypeInfo"], nil
    for _, chatType in ipairs(list) do
        local t = info[chatType]
        if Near(Safe.Num(t.r), r) and Near(Safe.Num(t.g), g) and Near(Safe.Num(t.b), b) then
            if hit then return nil end  -- same colour too: undecidable
            hit = chatType
        end
    end
    return hit
end

function Mirror.ChatTypes(infoID)
    local id = Safe.Num(infoID)
    return id and Candidates(id) or nil
end

function Mirror.SharedIDs()
    Rebuild()
    local out = {}
    for id, list in pairs(typesOf) do
        if #list > 1 then out[#out + 1] = { id, list } end
    end
    table.sort(out, function(x, y) return x[1] < y[1] end)
    return out
end

-- the line's event: the argument when passed, else from the type id
local function EventOf(infoID, event, r, g, b)
    local e = Safe.Str(event)
    if e then return e end
    local chatType = Mirror.ChatType(infoID, r, g, b)
    return chatType and ("CHAT_MSG_" .. chatType) or nil
end
Mirror._EventOf = EventOf

local function IsWhisper(event) return event ~= nil and WHISPER_EVENTS[event] == true end

local sink
local buffer = {}  -- lines before the sink exists

local function Forward(index, text, r, g, b, infoID, event)
    event = EventOf(infoID, event, r, g, b)
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

ns.Listen("ADDON_LOADED", function(_, name)
    if name ~= addonName or not ns.acct or not ns.acct.enabled then return end
    if ns.Conflict.Find() then return end
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
    Mirror.Refresh()
    ns.Listen("UPDATE_CHAT_COLOR", Mirror.Refresh)
    local function Again() if ns.active then Mirror.Refresh(); Mirror.HookAll(); Mirror.Hush() end end
    ns.Listen("UPDATE_CHAT_WINDOWS", Again)
    ns.Listen("UPDATE_FLOATING_CHAT_WINDOWS", Again)
    ns.Listen("PLAYER_ENTERING_WORLD", Again)
end)
