--[[
  Tabs: Blizzard's mirrored chat windows plus our own tabs (a new Blizzard window needs
  FCF_OpenNewWindow, which taints the chat frames). Own tabs sort the lines Blizzard already added by
  kind (event, channel link, info.id), never by text (secret in lockdown); General shows everything
  not switched off there. ns.acct.tabs = { { id, name, take = { [key] = label } } },
  ns.acct.generalHide = { [key] = true }; key = a kind or "channel:<name>"; own index = OWN_BASE + id.
  Tabs.All() / Name(index) / Get(index) / Route(index, infoID, event, text, r, g, b) / KeyFor(...)
  Tabs.Channels(take) / ChannelType(key) / Take(index) / Save(index, name, take) / Delete(index)
]]
local _, ns = ...
local Safe, Mirror, ChatKinds = ns.Safe, ns.Mirror, ns.ChatKinds

local Tabs = {}
ns.Tabs = Tabs

local OWN_BASE = 100

-- keys of tabs saved before the kinds existed -> kinds
local OLD = {
    say    = { "SAY", "YELL", "EMOTE" },
    guild  = { "GUILD", "OFFICER", "GUILD_ACHIEVEMENT" },
    group  = { "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER" },
    loot   = { "LOOT", "MONEY", "CURRENCY" },
    system = { "SYSTEM", "SKILL", "COMBAT_FACTION_CHANGE", "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "ACHIEVEMENT" },
}

local function Hidden()
    ns.acct.generalHide = ns.acct.generalHide or {}
    return ns.acct.generalHide
end

local function Convert(t)
    local take = {}
    for key, label in pairs(t.take or {}) do
        if OLD[key] then
            for _, kind in ipairs(OLD[key]) do take[kind] = ChatKinds.Label(kind); Hidden()[kind] = true end
        else
            take[key] = label
            if key:match("^channel:") then Hidden()[key] = true end
        end
    end
    t.take, t.kinds = take, true
end

local function List()
    ns.acct.tabs = ns.acct.tabs or {}
    for _, t in ipairs(ns.acct.tabs) do
        if not t.kinds then Convert(t) end
    end
    return ns.acct.tabs
end
function Tabs.Get(index)
    if type(index) ~= "number" or index <= OWN_BASE then return nil end
    for _, t in ipairs(List()) do
        if OWN_BASE + t.id == index then return t end
    end
    return nil
end

function Tabs.All()
    local all = Mirror.Indices()
    for _, t in ipairs(List()) do all[#all + 1] = OWN_BASE + t.id end
    return all
end

function Tabs.Name(index)
    local t = Tabs.Get(index)
    if t then return t.name end
    return Mirror.Name(index)
end

-- "Trade - City" -> "channel:trade", "Trade" (the zone part changes)
local function ChannelKey(name)
    name = Safe.Str(name)
    if not name or name == "" then return nil end
    local base = name:match("^(.-)%s+%-%s") or name
    return "channel:" .. base:lower(), base
end

local function Channel(n)
    local fn = _G["GetChannelName"]
    if not fn then return nil end
    local ok, _, name = pcall(fn, n)
    if not ok then return nil end
    return ChannelKey(name)
end

local function MaxChannels() return _G["MAX_WOW_CHAT_CHANNELS"] or 20 end

-- a channel line carries its link ("|Hchannel:channel:2|h"): the number gives the key
local function LinkedChannel(text)
    text = Safe.Str(text)
    if not text then return nil end
    local n, name = text:match("|H[Cc]hannel:[Cc][Hh][Aa][Nn][Nn][Ee][Ll]:(%d+)|h%[%d+%.%s*([^%]]+)%]|h")
    if not n then return nil end
    return Channel(tonumber(n)) or (ChannelKey(name))
end

-- kind / channel key: the event (player messages only), the channel link, the type id
local function KeyOf(infoID, event, text, r, g, b)
    local e = Safe.Str(event)
    local chatType = e and e ~= "CHAT_MSG_CHANNEL" and e:match("^CHAT_MSG_(.+)$")
    if chatType then
        -- Mirror names a line without an event by its type: "CHAT_MSG_CHANNEL2"
        local n = chatType:match("^CHANNEL(%d+)$")
        if n then return LinkedChannel(text) or (Channel(tonumber(n))) end
        return ChatKinds.KeyOf(chatType)
    end
    local linked = LinkedChannel(text)
    if linked then return linked end
    chatType = Mirror.ChatType(infoID, r, g, b)
    if chatType then
        local n = chatType:match("^CHANNEL(%d+)$")
        if n then return (Channel(tonumber(n))) end
        return ChatKinds.KeyOf(chatType)
    end
    local key
    for _, t in ipairs(Mirror.ChatTypes(infoID) or {}) do
        local k = ChatKinds.KeyOf(t)
        if not k or (key and k ~= key) then return nil end
        key = k
    end
    return key
end

function Tabs.KeyFor(infoID, event, text, r, g, b) return KeyOf(infoID, event, text, r, g, b) end

-- a line Blizzard adds to two windows arrives twice in one frame: own tabs take it once
local recent, recentAt = {}, nil
local function Fresh(text, index)
    local plain = Safe.Str(text)
    if not plain then return true end
    local now = GetTime()
    if recentAt ~= now then wipe(recent); recentAt = now end
    local src = recent[plain]
    if src and src ~= index then return false end
    recent[plain] = index
    return true
end

function Tabs.Route(index, infoID, event, text, r, g, b)
    local list, hidden = List(), Hidden()
    if #list == 0 and (index ~= 1 or next(hidden) == nil) then return nil end
    local key = KeyOf(infoID, event, text, r, g, b)
    if not key then return nil end
    local out = {}
    if index ~= 1 or not hidden[key] then out[1] = index end
    if Fresh(text, index) then
        for _, t in ipairs(list) do
            if t.take and t.take[key] then out[#out + 1] = OWN_BASE + t.id end
        end
    end
    return out
end

function Tabs.Channels(take)
    local out, seen = {}, {}
    for n = 1, MaxChannels() do
        local key, label = Channel(n)
        if key and not seen[key] then
            seen[key] = true
            out[#out + 1] = { key, label }
        end
    end
    for key, label in pairs(take or {}) do
        if not seen[key] and key:match("^channel:") then
            seen[key] = true
            out[#out + 1] = { key, label }
        end
    end
    return out
end

function Tabs.ChannelType(key)
    for n = 1, MaxChannels() do
        if Channel(n) == key then return "CHANNEL" .. n end
    end
    return nil
end

function Tabs.Take(index)
    local take = {}
    if index == 1 then
        local hidden = Hidden()
        for _, kind in ipairs(ChatKinds.All()) do
            if not hidden[kind] then take[kind] = ChatKinds.Label(kind) end
        end
        for _, c in ipairs(Tabs.Channels()) do
            if not hidden[c[1]] then take[c[1]] = c[2] end
        end
        return take
    end
    local t = Tabs.Get(index)
    for key, label in pairs(t and t.take or {}) do take[key] = label end
    return take
end

local function SaveGeneral(take)
    local hidden, old = {}, Hidden()
    for _, kind in ipairs(ChatKinds.All()) do
        if not take[kind] then hidden[kind] = true end
    end
    local joined = {}
    for _, c in ipairs(Tabs.Channels()) do
        joined[c[1]] = true
        if not take[c[1]] then hidden[c[1]] = true end
    end
    for key in pairs(old) do
        if key:match("^channel:") and not joined[key] and not take[key] then hidden[key] = true end
    end
    ns.acct.generalHide = hidden
    return 1
end

function Tabs.Save(index, name, take)
    if index == 1 then return SaveGeneral(take) end
    local t = Tabs.Get(index)
    if not t then
        local id = 1
        for _, o in ipairs(List()) do if o.id >= id then id = o.id + 1 end end
        t = { id = id, kinds = true }
        List()[#List() + 1] = t
    end
    t.name = name
    t.take = take
    return OWN_BASE + t.id
end

function Tabs.Delete(index)
    local list = List()
    for k, t in ipairs(list) do
        if OWN_BASE + t.id == index then
            table.remove(list, k)
            wipe(ns.History.Lines(index))
            return
        end
    end
end
